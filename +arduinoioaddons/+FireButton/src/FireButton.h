#pragma once

#include "LibraryBase.h"

class FireButton : public LibraryBase
{
public:
    FireButton(MWArduinoClass& arduino)
    {
        libName = "FireButton/FireButton";
        arduino.registerLibrary(this);
    }

    void loop() override
    {
        if (state == WaitingForRelease || state == WaitingForPress) {
            sample();
        }
    }

    void commandHandler(byte command, byte* data, unsigned int length) override
    {
        if (command == Configure && length == 2) {
            pin = data[0];
            pressedLevel = data[1];
            state = Disabled;
            pressCount = 0;
        } else if (command == SetEnabled && length == 1) {
            // Each phase starts empty and must see a stable release first.
            state = data[0] ? WaitingForRelease : Disabled;
            pressCount = 0;
            releasedAt = micros();
            pressPending = false;
        } else if (command == ReadPresses) {
            byte level = sample();
            byte response[] = {pressCount, level, byte(state == WaitingForPress)};
            pressCount = 0;
            sendResponseMsg(command, response, sizeof(response));
            return;
        }
        sendResponseMsg(command, 0, 0);
    }

private:
    enum Command : byte { Configure = 1, SetEnabled = 2, ReadPresses = 3 };
    enum State : byte { Disabled, WaitingForRelease, WaitingForPress, Complete };
    static constexpr unsigned long ReleaseDebounceMicros = 60000;
    static constexpr unsigned long PressDebounceMicros = 20000;

    byte pin = 0;
    byte pressedLevel = HIGH;
    byte pressCount = 0;
    State state = Disabled;
    bool pressPending = false;
    unsigned long releasedAt = 0;
    unsigned long pressedAt = 0;

    byte sample()
    {
        byte level = digitalRead(pin);
        bool pressed = level == pressedLevel;
        unsigned long now = micros();

        if (state == WaitingForRelease) {
            if (pressed) {
                releasedAt = now;
            } else if (now - releasedAt >= ReleaseDebounceMicros) {
                state = WaitingForPress;
            }
        } else if (state == WaitingForPress) {
            if (!pressed) {
                pressPending = false;
            } else if (!pressPending) {
                pressedAt = now;
                pressPending = true;
            } else if (now - pressedAt >= PressDebounceMicros) {
                // One event per phase, retained until MATLAB reads it.
                pressCount = 1;
                state = Complete;
            }
        }
        return level;
    }
};
