Candidate__c candidate = new Candidate__c(
    First_Name__c = 'sMOKE',
    Last_Name__c = 'SMoKe',
    Email__c = 'normalize+' + Datetime.now().getTime() + '@example.com',
    Phone__c = '555-0123',
    Status__c = 'Active',
    Education_Level__c = 'Bachelor',
    Expected_Salary__c = 90000
);

insert candidate;

Candidate__c saved = [
    SELECT First_Name__c, Last_Name__c
    FROM Candidate__c
    WHERE Id = :candidate.Id
];

System.assertEquals('Smoke', saved.First_Name__c, 'First name should be normalized.');
System.assertEquals('Smoke', saved.Last_Name__c, 'Last name should be normalized.');
System.debug('CH5 CANDIDATE NAME NORMALIZATION OK: ' + saved.First_Name__c + ' ' + saved.Last_Name__c);
