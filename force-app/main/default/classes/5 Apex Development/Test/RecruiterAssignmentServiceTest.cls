@IsTest
private class RecruiterAssignmentServiceTest {
    @IsTest
    static void fallsBackToCurrentUserWhenNoWorkloadRowsExist() {
        Id appId = Id.valueOf('a02000000000001AAA');
        Map<Id, Id> assignments = RecruiterAssignmentService.assign(new Set<Id>{ appId });
        System.assertEquals(UserInfo.getUserId(), assignments.get(appId));
    }
}
