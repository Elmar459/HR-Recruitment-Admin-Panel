System.assertEquals(true, StatusTransitionValidator.validate('New', 'Screening'));
System.assertEquals(false, StatusTransitionValidator.validate('New', 'Interview 3'));
System.assert(StatusTransitionValidator.getNextAllowedStatuses('Offer').contains('Hired'));

Application__c app = (Application__c) JSON.deserialize(
    '{"attributes":{"type":"Application__c"},"Days_in_Stage__c":6}',
    Application__c.class
);

SLAMonitorService.markBreaches(new List<Application__c>{ app }, null);

System.assertEquals(true, app.SLA_Breach__c, 'Expected SLA breach flag.');
System.assertEquals(Date.today(), app.SLA_Breach_Date__c, 'Expected SLA breach date.');
System.debug('CH5 STATUS/SLA OK');
