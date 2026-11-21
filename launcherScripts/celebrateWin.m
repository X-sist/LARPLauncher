function celebrateWin(register, scores, currentPlayer)
    % Controls are inactive while the winning three LEDs stay lit.
    scoreBits = updateLEDs(register, scores, currentPlayer);
    pause(1);
    for flash = 1:3
        write(register, uint8(255), 'uint8');
        pause(0.20);
        write(register, scoreBits(currentPlayer), 'uint8');
        pause(0.20);
    end
end
