function waitForFireButtonPress(fireButton, loopPause)
    % Start a fresh capture so each phase requires its own button press.
    stopFireCapture = onCleanup(@() fireButton.enableCapture(false));
    fireButton.enableCapture(true);
    while fireButton.takePresses() == 0
        pause(loopPause);
    end
end
