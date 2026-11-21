function scores = scorePoint(scores, currentPlayer)
    scores(currentPlayer) = scores(currentPlayer) + 1;
    fprintf('Player %d | CPU %d\n', scores(1), scores(2));
end
