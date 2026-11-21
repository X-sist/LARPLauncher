function scoreBits = updateLEDs(register, scores, currentPlayer)
    % QA and QH show the turn. QB-QD and QE-QG fill as each side scores.
    scoreBits = bitshift(uint8(2 .^ scores - 1), [1, 4]);
    turnBit = bitshift(uint8(1), 7 * (currentPlayer - 1));
    ledByte = bitor(bitor(scoreBits(1), scoreBits(2)), turnBit);
    write(register, ledByte, 'uint8');
end
