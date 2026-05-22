@IsTest
private class StatusTransitionValidatorTest {
    @IsTest
    static void validatesAllowedAndBlockedTransitions() {
        System.assertEquals(true, StatusTransitionValidator.validate('New', 'Screening'));
        System.assertEquals(false, StatusTransitionValidator.validate('New', 'Interview 3'));
        System.assert(StatusTransitionValidator.getNextAllowedStatuses('Offer').contains('Hired'));
    }
}
