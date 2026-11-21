function fireBall(firingServo, settings)
    resetFiringServo = onCleanup(@() writePosition(firingServo, settings.fireHome));
    writePosition(firingServo, settings.firePosition);
    pause(settings.fireDwell);
    writePosition(firingServo, settings.fireHome);
    pause(settings.fireReturnTime);
end
