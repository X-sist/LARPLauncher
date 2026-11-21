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
        if (enabled) {
            sample();
        }
    }

    void commandHandler(byte command, byte* data, unsigned int length) override
    {
        if (command == Configure && length == 2) {
            pin = data[0];
            pressedLevel = data[1];
            enabled = false;
            pressCount = 0;
        } else if (command == SetEnabled && length == 1) {
            enabled = data[0] != 0;
            pressCount = 0;
            wasPressed = digitalRead(pin) == pressedLevel;
            armed = !wasPressed;
        } else if (command == ReadPresses) {
            byte level = sample();
            byte response[] = {pressCount, level};
            pressCount = 0;
            sendResponseMsg(command, response, sizeof(response));
            return;
        }
        sendResponseMsg(command, 0, 0);
    }

private:
    enum Command : byte { Configure = 1, SetEnabled = 2, ReadPresses = 3 };
    static constexpr unsigned long ReleaseDebounceMicros = 40000;

    byte pin = 0;
    byte pressedLevel = HIGH;
    byte pressCount = 0;
    bool enabled = false;
    bool armed = false;
    bool wasPressed = false;
    unsigned long releasedAt = 0;

    byte sample()
    {
        byte level = digitalRead(pin);
        if (!enabled) {
            return level;
        }

        bool pressed = level == pressedLevel;
        if (pressed) {
            // Latch the first sample. Debounce the release before rearming.
            if (armed && pressCount < 255) {
                ++pressCount;
            }
            armed = false;
        } else if (!armed) {
            unsigned long now = micros();
            if (wasPressed) {
                releasedAt = now;
            }
            armed = now - releasedAt >= ReleaseDebounceMicros;
        }
        wasPressed = pressed;
        return level;
    }
};
