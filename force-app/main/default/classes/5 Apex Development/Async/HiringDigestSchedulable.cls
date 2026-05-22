global class HiringDigestSchedulable implements Schedulable {
    global void execute(SchedulableContext context) {
        AggregateResult[] rows = [
            SELECT Status__c statusName, COUNT(Id) total
            FROM Application__c
            WHERE CreatedDate = LAST_N_DAYS:7
            GROUP BY Status__c
        ];
        NotificationService.logMessage('Digest', null, 'Weekly hiring digest rows: ' + rows.size());
    }
}
