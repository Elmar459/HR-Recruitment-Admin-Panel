Candidate__c candidate = new Candidate__c(
    First_Name__c = 'Smoke',
    Last_Name__c = 'Candidate',
    Email__c = 'smoke+' + Datetime.now().getTime() + '@example.com',
    Phone__c = '555-0199',
    Status__c = 'Active',
    Education_Level__c = 'Bachelor',
    Expected_Salary__c = 90000,
    Location__c = 'Baku',
    Remote_Work__c = true
);

Position__c position = new Position__c(
    Department__c = 'IT',
    Status__c = 'Open',
    Education_Level__c = 'Bachelor',
    Headcount__c = 1,
    Priority__c = 'High',
    Open_Date__c = Date.today(),
    Salary_Min__c = 80000,
    Salary_Max__c = 100000,
    Location__c = 'Baku',
    Remote_Eligible__c = true
);

Skill__c skill = new Skill__c(
    Name = 'Smoke Apex ' + Datetime.now().getTime(),
    Category__c = 'Technical',
    Level__c = 'Advanced'
);

insert new List<SObject>{ candidate, position, skill };

insert new Candidate_Skill__c(
    Candidate__c = candidate.Id,
    Skill__c = skill.Id,
    Proficiency_Level__c = 'Advanced',
    Years_of_Experience_with_Skill__c = 4
);

insert new Position_Skill__c(
    Position__c = position.Id,
    Skill__c = skill.Id,
    Weight__c = 4,
    Minimum_Level__c = 'Intermediate',
    Is_Mandatory__c = true
);

Application__c app = new Application__c(
    Candidate__c = candidate.Id,
    Position__c = position.Id,
    Status__c = 'New',
    Applied_Date__c = Date.today()
);
insert app;

Decimal score = CandidateMatchingService.scoreApplication(app.Id);
MatchResult details = CandidateMatchingService.getMatchDetails(app.Id);

System.assert(score > 0, 'Expected a positive match score.');
System.assert(details.breakdown.size() == 5, 'Expected five scoring criteria.');
System.debug('CH5 MATCHING OK: score=' + score + ', details=' + details.summary);
