function waitForFireButtonPress(fireButton, loopPause, phase)
    % Every wait owns a fresh, one-shot capture; no presses cross phases.
    if nargin < 3
        phase = '[Fire]';
    end
    stopFireCapture = onCleanup(@() fireButton.enableCapture(false));
    fireButton.enableCapture(true);
    fprintf('%s Release Fire to arm this phase.\n', phase);
    reportedReady = false;
    while true
        [count, ~, ready] = fireButton.takePresses();
        if count > 0
            fprintf('%s Fresh Fire press accepted.\n', phase);
            return;
        end
        if ready && ~reportedReady
            fprintf('%s READY: press Fire once.\n', phase);
            reportedReady = true;
        end
        pause(loopPause);
    end
end
