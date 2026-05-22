public with sharing class RecruitmentLwcController {
    private static final String APPLICATION_OBJECT = 'Application__c';
    private static final String INTERVIEW_OBJECT = 'Interview__c';
    private static final String FEEDBACK_OBJECT = 'Interview_Feedback__c';
    private static final String MESSAGE_OBJECT = 'Message__c';
    private static final String MESSAGE_EVENT = 'Recruitment_Message__e';
    private static final String PIPELINE_EVENT = 'Application_Pipeline_Update__e';

    @AuraEnabled(cacheable=true)
    public static List<PipelineStage> getPipelineBoard() {
        List<String> statuses = getApplicationStatuses();
        Map<String, PipelineStage> stagesByStatus = new Map<String, PipelineStage>();
        for (String status : statuses) {
            stagesByStatus.put(status, new PipelineStage(status));
        }

        if (!objectExists(APPLICATION_OBJECT)) {
            return stagesByStatus.values();
        }

        for (SObject app : Database.query(buildApplicationQuery())) {
            String status = asString(getIfPresent(app, 'Status__c'));
            if (String.isBlank(status)) {
                status = 'New';
            }
            if (!stagesByStatus.containsKey(status)) {
                stagesByStatus.put(status, new PipelineStage(status));
            }
            stagesByStatus.get(status).applications.add(toPipelineCard(app));
        }

        return stagesByStatus.values();
    }

    @AuraEnabled
    public static void updateApplicationStatus(Id applicationId, String newStatus) {
        if (applicationId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('Application and status are required.');
        }

        Application__c current = [
            SELECT Id, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];
        if (!StatusTransitionValidator.validate(current.Status__c, newStatus)) {
            throw new AuraHandledException(
                'Invalid status transition from ' + current.Status__c + ' to ' + newStatus + '.'
            );
        }

        SObject app = Schema.getGlobalDescribe().get(APPLICATION_OBJECT).newSObject(applicationId);
        app.put('Status__c', newStatus);
        if (fieldExists(APPLICATION_OBJECT, 'Last_Stage_Change_Date__c')) {
            app.put('Last_Stage_Change_Date__c', Date.today());
        }
        update app;

        NotificationService.sendStatusUpdate(applicationId, newStatus);
        publishPipelineEvent(applicationId, newStatus);
    }

    @AuraEnabled(cacheable=true)
    public static TimelinePayload getInterviewTimeline(Id applicationId) {
        TimelinePayload payload = new TimelinePayload();
        if (applicationId == null || !objectExists(APPLICATION_OBJECT)) {
            return payload;
        }

        SObject app = Database.query(buildApplicationDetailQuery(applicationId));
        payload.application = toApplicationSummary(app);
        payload.statusOptions = getStatusOptions(payload.application.status);

        if (objectExists(INTERVIEW_OBJECT)) {
            for (SObject interview : Database.query(buildInterviewQuery(applicationId))) {
                payload.interviews.add(toInterviewItem(interview));
            }
        }

        payload.stages = buildStageItems(payload.interviews, payload.application.status);
        payload.scoreTrend = buildScoreTrend(payload.stages);
        payload.matchDetails = buildMatchDetails(applicationId, app);
        return payload;
    }

    @AuraEnabled
    public static Id scheduleNextInterview(Id applicationId) {
        if (applicationId == null) {
            throw new AuraHandledException('Application is required.');
        }

        TimelinePayload timeline = getInterviewTimeline(applicationId);
        String nextType = 'Phone Screen';
        for (StageItem stage : timeline.stages) {
            if (stage.state != 'completed') {
                nextType = stage.type;
                if (stage.interview != null && (stage.interview.status == 'Scheduled' || stage.interview.status == 'In Progress')) {
                    return stage.interview.id;
                }
                break;
            }
        }

        Datetime startTime = nextBusinessSlot();
        return InterviewService.scheduleInterview(applicationId, UserInfo.getUserId(), startTime, nextType);
    }

    @AuraEnabled(cacheable=true)
    public static List<MessageItem> getMessages(Id applicationId) {
        List<MessageItem> messages = new List<MessageItem>();
        if (applicationId == null || !objectExists(MESSAGE_OBJECT) || !hasMessageLinkField()) {
            return messages;
        }

        for (SObject message : Database.query(buildMessageQuery(applicationId))) {
            messages.add(toMessageItem(message));
        }
        return messages;
    }

    @AuraEnabled
    public static MessageItem sendMessage(Id applicationId, String body) {
        if (applicationId == null || String.isBlank(body)) {
            throw new AuraHandledException('Application and message body are required.');
        }

        MessageItem item = new MessageItem();
        item.applicationId = applicationId;
        item.body = body.trim();
        item.direction = 'Outbound';
        item.createdDate = System.now();
        item.createdByName = UserInfo.getName();

        if (objectExists(MESSAGE_OBJECT)) {
            SObject message = Schema.getGlobalDescribe().get(MESSAGE_OBJECT).newSObject();
            putIfPresent(message, 'Related_Record_Id__c', String.valueOf(applicationId));
            putIfPresent(message, 'Application__c', applicationId);
            putIfPresent(message, 'Body__c', item.body);
            putIfPresent(message, 'Subject__c', 'Recruitment message');
            putIfPresent(message, 'Direction__c', item.direction);
            putIfPresent(message, 'Channel__c', 'Portal');
            putIfPresent(message, 'Status__c', 'Sent');
            insert message;
            item.id = (Id) message.get('Id');
        }

        publishMessageEvent(item);
        return item;
    }

    private static PipelineCard toPipelineCard(SObject app) {
        PipelineCard card = new PipelineCard();
        card.id = (Id) app.get('Id');
        card.status = asString(getIfPresent(app, 'Status__c'));
        card.candidateName = relatedName(app, 'Candidate__r');
        card.positionName = relatedName(app, 'Position__r');
        card.matchScore = asDecimal(getIfPresent(app, 'Match_Score__c'));
        card.appliedDate = (Date) getIfPresent(app, 'Applied_Date__c');
        card.daysInStage = asDecimal(getIfPresent(app, 'Days_in_Stage__c'));
        card.slaBreached = asBoolean(getIfPresent(app, 'SLA_Breach__c'));
        card.priority = relatedField(app, 'Position__r', 'Priority__c');
        return card;
    }

    private static ApplicationSummary toApplicationSummary(SObject app) {
        ApplicationSummary summary = new ApplicationSummary();
        summary.id = (Id) app.get('Id');
        summary.candidateId = (Id) getIfPresent(app, 'Candidate__c');
        summary.positionId = (Id) getIfPresent(app, 'Position__c');
        summary.status = asString(getIfPresent(app, 'Status__c'));
        summary.candidateName = relatedName(app, 'Candidate__r');
        summary.positionName = relatedName(app, 'Position__r');
        summary.matchScore = asDecimal(getIfPresent(app, 'Match_Score__c'));
        summary.daysInStage = asDecimal(getIfPresent(app, 'Days_in_Stage__c'));
        summary.slaBreached = asBoolean(getIfPresent(app, 'SLA_Breach__c'));
        summary.slaDaysRemaining = 7 - (summary.daysInStage == null ? 0 : summary.daysInStage);
        return summary;
    }

    private static InterviewItem toInterviewItem(SObject interview) {
        InterviewItem item = new InterviewItem();
        item.id = (Id) interview.get('Id');
        item.type = asString(getIfPresent(interview, 'Type__c'));
        item.status = asString(getIfPresent(interview, 'Status__c'));
        item.dateTimeValue = (Datetime) getIfPresent(interview, 'Date_Time__c');
        item.score = asDecimal(getIfPresent(interview, 'Average_Interview_Score__c'));
        item.interviewerName = relatedName(interview, 'Interviewer__r');
        item.recommendation = asString(getIfPresent(interview, 'Recommendation__c'));
        item.feedback = asString(getIfPresent(interview, 'Feedback_Summary__c'));
        item.feedbackDetails = getFeedbackItem(item.id);
        return item;
    }

    private static List<MatchDetail> buildMatchDetails(Id applicationId, SObject app) {
        List<MatchDetail> details = new List<MatchDetail>();
        try {
            MatchResult result = CandidateMatchingService.getMatchDetails(applicationId);
            for (CriterionScore criterion : result.breakdown) {
                addDetail(details, criterion.name, criterion.rawScore, criterion.weightedScore);
            }
        } catch (Exception e) {
            addDetail(details, 'Overall Match', asDecimal(getIfPresent(app, 'Match_Score__c')), null);
        }
        return details;
    }

    private static void addDetail(List<MatchDetail> details, String label, Decimal value, Decimal weightedValue) {
        if (value == null) {
            return;
        }
        MatchDetail detail = new MatchDetail();
        detail.label = label;
        detail.value = value;
        detail.weightedValue = weightedValue;
        details.add(detail);
    }

    private static List<StageItem> buildStageItems(List<InterviewItem> interviews, String applicationStatus) {
        List<String> stageTypes = new List<String>{ 'Phone Screen', 'Technical', 'HR/Behavioral', 'Cultural Fit', 'Final/Executive' };
        List<StageItem> stages = new List<StageItem>();
        Integer activeIndex = activeStageIndex(applicationStatus, interviews);

        for (Integer i = 0; i < stageTypes.size(); i++) {
            StageItem stage = new StageItem();
            stage.numberValue = i + 1;
            stage.type = stageTypes[i];
            stage.state = i < activeIndex ? 'completed' : i == activeIndex ? 'active' : 'pending';
            for (InterviewItem interview : interviews) {
                if (interview.type != null && interview.type.contains(stage.type)) {
                    stage.interview = interview;
                    stage.status = interview.status;
                    stage.dateTimeValue = interview.dateTimeValue;
                    stage.score = interview.score;
                    if (interview.status == 'Completed') {
                        stage.state = 'completed';
                    } else if (interview.status == 'Cancelled' || interview.status == 'No Show') {
                        stage.state = 'rejected';
                    }
                    break;
                }
            }
            if (stage.status == null) {
                stage.status = stage.state == 'pending' ? 'Pending' : 'Active';
            }
            stages.add(stage);
        }
        return stages;
    }

    private static Integer activeStageIndex(String applicationStatus, List<InterviewItem> interviews) {
        if (applicationStatus != null && applicationStatus.startsWith('Interview ')) {
            String stageNumber = applicationStatus.replace('Interview ', '');
            try {
                return Math.max(0, Math.min(4, Integer.valueOf(stageNumber) - 1));
            } catch (Exception e) {
                return 0;
            }
        }
        Integer completed = 0;
        for (InterviewItem interview : interviews) {
            if (interview.status == 'Completed') {
                completed++;
            }
        }
        return Math.max(0, Math.min(4, completed));
    }

    private static List<ScoreTrendPoint> buildScoreTrend(List<StageItem> stages) {
        List<ScoreTrendPoint> points = new List<ScoreTrendPoint>();
        for (StageItem stage : stages) {
            if (stage.state == 'completed' && stage.interview != null && stage.interview.feedbackDetails != null) {
                ScoreTrendPoint point = new ScoreTrendPoint();
                point.label = stage.type;
                point.score = stage.interview.feedbackDetails.compositeScore != null
                    ? stage.interview.feedbackDetails.compositeScore
                    : stage.score;
                points.add(point);
            }
        }
        return points;
    }

    private static FeedbackItem getFeedbackItem(Id interviewId) {
        if (interviewId == null || !objectExists(FEEDBACK_OBJECT)) {
            return null;
        }
        List<SObject> feedbackRecords = Database.query(buildFeedbackQuery(interviewId));
        if (feedbackRecords.isEmpty()) {
            return null;
        }
        SObject feedback = feedbackRecords[0];
        FeedbackItem item = new FeedbackItem();
        item.id = (Id) feedback.get('Id');
        item.technicalScore = asDecimal(getIfPresent(feedback, 'Technical_Score__c'));
        item.communicationScore = asDecimal(getIfPresent(feedback, 'Communication_Score__c'));
        item.cultureFitScore = asDecimal(getIfPresent(feedback, 'Culture_Fit_Score__c'));
        item.compositeScore = asDecimal(getIfPresent(feedback, 'Composite_Score__c'));
        item.strengths = asString(getFirstPresent(feedback, new List<String>{ 'Strengths__c', 'Strength__c' }));
        item.weaknesses = asString(getFirstPresent(feedback, new List<String>{ 'Weaknesses__c', 'Weakness__c' }));
        item.comments = asString(getIfPresent(feedback, 'Comments__c'));
        item.recommendation = asString(getIfPresent(feedback, 'Recommendation__c'));
        return item;
    }

    private static MessageItem toMessageItem(SObject message) {
        MessageItem item = new MessageItem();
        item.id = (Id) message.get('Id');
        item.body = asString(getIfPresent(message, 'Body__c'));
        item.direction = asString(getIfPresent(message, 'Direction__c'));
        item.createdDate = (Datetime) getIfPresent(message, 'CreatedDate');
        item.createdByName = relatedName(message, 'CreatedBy');
        return item;
    }

    private static String buildApplicationQuery() {
        List<String> fields = new List<String>{ 'Id', 'Status__c' };
        addField(fields, APPLICATION_OBJECT, 'Applied_Date__c');
        addField(fields, APPLICATION_OBJECT, 'Match_Score__c');
        addField(fields, APPLICATION_OBJECT, 'Days_in_Stage__c');
        addField(fields, APPLICATION_OBJECT, 'SLA_Breach__c');
        fields.add('Candidate__r.Name');
        addRelationshipField(fields, 'Candidate__r', 'First_Name__c');
        addRelationshipField(fields, 'Candidate__r', 'Last_Name__c');
        fields.add('Position__r.Name');
        addRelationshipField(fields, 'Position__r', 'Priority__c');
        return 'SELECT ' + String.join(fields, ',')
            + ' FROM Application__c ORDER BY Status__c, SLA_Breach__c DESC, Match_Score__c DESC NULLS LAST';
    }

    private static String buildApplicationDetailQuery(Id applicationId) {
        List<String> fields = new List<String>{ 'Id', 'Status__c' };
        addField(fields, APPLICATION_OBJECT, 'Match_Score__c');
        addField(fields, APPLICATION_OBJECT, 'Days_in_Stage__c');
        addField(fields, APPLICATION_OBJECT, 'SLA_Breach__c');
        fields.add('Candidate__r.Name');
        addRelationshipField(fields, 'Candidate__r', 'First_Name__c');
        addRelationshipField(fields, 'Candidate__r', 'Last_Name__c');
        fields.add('Position__r.Name');
        addField(fields, APPLICATION_OBJECT, 'Candidate__c');
        addField(fields, APPLICATION_OBJECT, 'Position__c');
        return 'SELECT ' + String.join(fields, ',')
            + ' FROM Application__c WHERE Id = \'' + String.escapeSingleQuotes(String.valueOf(applicationId)) + '\' LIMIT 1';
    }

    private static String buildInterviewQuery(Id applicationId) {
        List<String> fields = new List<String>{ 'Id' };
        addField(fields, INTERVIEW_OBJECT, 'Type__c');
        addField(fields, INTERVIEW_OBJECT, 'Status__c');
        addField(fields, INTERVIEW_OBJECT, 'Date_Time__c');
        addField(fields, INTERVIEW_OBJECT, 'Average_Interview_Score__c');
        addField(fields, INTERVIEW_OBJECT, 'Recommendation__c');
        addField(fields, INTERVIEW_OBJECT, 'Feedback_Summary__c');
        fields.add('Interviewer__r.Name');
        return 'SELECT ' + String.join(fields, ',')
            + ' FROM Interview__c WHERE Application__c = \'' + String.escapeSingleQuotes(String.valueOf(applicationId))
            + '\' ORDER BY Date_Time__c ASC NULLS LAST';
    }

    private static String buildFeedbackQuery(Id interviewId) {
        List<String> fields = new List<String>{ 'Id' };
        addField(fields, FEEDBACK_OBJECT, 'Technical_Score__c');
        addField(fields, FEEDBACK_OBJECT, 'Communication_Score__c');
        addField(fields, FEEDBACK_OBJECT, 'Culture_Fit_Score__c');
        addField(fields, FEEDBACK_OBJECT, 'Composite_Score__c');
        addField(fields, FEEDBACK_OBJECT, 'Strengths__c');
        addField(fields, FEEDBACK_OBJECT, 'Strength__c');
        addField(fields, FEEDBACK_OBJECT, 'Weaknesses__c');
        addField(fields, FEEDBACK_OBJECT, 'Weakness__c');
        addField(fields, FEEDBACK_OBJECT, 'Comments__c');
        addField(fields, FEEDBACK_OBJECT, 'Recommendation__c');
        return 'SELECT ' + String.join(fields, ',')
            + ' FROM Interview_Feedback__c WHERE Interview__c = \'' + String.escapeSingleQuotes(String.valueOf(interviewId))
            + '\' ORDER BY Submitted_At__c DESC NULLS LAST LIMIT 1';
    }

    private static String buildMessageQuery(Id applicationId) {
        List<String> fields = new List<String>{ 'Id', 'CreatedDate', 'CreatedBy.Name' };
        addField(fields, MESSAGE_OBJECT, 'Body__c');
        addField(fields, MESSAGE_OBJECT, 'Direction__c');

        String whereClause = fieldExists(MESSAGE_OBJECT, 'Application__c')
            ? 'Application__c = \'' + String.escapeSingleQuotes(String.valueOf(applicationId)) + '\''
            : 'Related_Record_Id__c = \'' + String.escapeSingleQuotes(String.valueOf(applicationId)) + '\'';

        return 'SELECT ' + String.join(fields, ',')
            + ' FROM Message__c WHERE ' + whereClause + ' ORDER BY CreatedDate ASC LIMIT 100';
    }

    private static Boolean hasMessageLinkField() {
        return fieldExists(MESSAGE_OBJECT, 'Application__c') || fieldExists(MESSAGE_OBJECT, 'Related_Record_Id__c');
    }

    private static List<String> getApplicationStatuses() {
        List<String> statuses = new List<String>();
        if (fieldExists(APPLICATION_OBJECT, 'Status__c')) {
            Schema.DescribeFieldResult describe = Schema.getGlobalDescribe()
                .get(APPLICATION_OBJECT)
                .getDescribe()
                .fields.getMap()
                .get('Status__c')
                .getDescribe();
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry.isActive()) {
                    statuses.add(entry.getValue());
                }
            }
        }
        if (statuses.isEmpty()) {
            statuses.addAll(new List<String>{ 'New', 'Screening', 'Interview 1', 'Interview 2', 'Offer', 'Hired', 'Rejected' });
        }
        return statuses;
    }

    private static List<StatusOption> getStatusOptions(String currentStatus) {
        List<StatusOption> options = new List<StatusOption>();
        Set<String> allowed = new Set<String>();
        if (!String.isBlank(currentStatus)) {
            allowed.add(currentStatus);
            allowed.addAll(StatusTransitionValidator.getNextAllowedStatuses(currentStatus));
        }
        if (allowed.isEmpty()) {
            allowed.addAll(getApplicationStatuses());
        }

        for (String status : getApplicationStatuses()) {
            if (allowed.contains(status)) {
                StatusOption option = new StatusOption();
                option.label = status;
                option.value = status;
                options.add(option);
            }
        }
        return options;
    }

    private static void publishMessageEvent(MessageItem item) {
        if (!objectExists(MESSAGE_EVENT)) {
            return;
        }
        SObject eventRecord = Schema.getGlobalDescribe().get(MESSAGE_EVENT).newSObject();
        putIfPresent(eventRecord, 'Application_Id__c', String.valueOf(item.applicationId));
        putIfPresent(eventRecord, 'Message_Body__c', item.body);
        putIfPresent(eventRecord, 'Direction__c', item.direction);
        EventBus.publish(eventRecord);
    }

    private static void publishPipelineEvent(Id applicationId, String status) {
        if (!objectExists(PIPELINE_EVENT)) {
            return;
        }
        SObject eventRecord = Schema.getGlobalDescribe().get(PIPELINE_EVENT).newSObject();
        putIfPresent(eventRecord, 'Application_Id__c', String.valueOf(applicationId));
        putIfPresent(eventRecord, 'Status__c', status);
        EventBus.publish(eventRecord);
    }

    private static void addField(List<String> fields, String objectName, String fieldName) {
        if (fieldExists(objectName, fieldName)) {
            fields.add(fieldName);
        }
    }

    private static void addRelationshipField(List<String> fields, String relationshipName, String fieldName) {
        fields.add(relationshipName + '.' + fieldName);
    }

    private static Object getIfPresent(SObject record, String fieldName) {
        if (record == null || !record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            return null;
        }
        try {
            return record.get(fieldName);
        } catch (SObjectException e) {
            return null;
        }
    }

    private static Object getFirstPresent(SObject record, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            Object value = getIfPresent(record, fieldName);
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private static Datetime nextBusinessSlot() {
        Datetime slot = System.now().addDays(1);
        slot = Datetime.newInstance(slot.date(), Time.newInstance(10, 0, 0, 0));
        while (slot.format('E') == 'Sat' || slot.format('E') == 'Sun') {
            slot = slot.addDays(1);
        }
        return slot;
    }

    private static Boolean objectExists(String objectName) {
        return Schema.getGlobalDescribe().containsKey(objectName);
    }

    private static Boolean fieldExists(String objectName, String fieldName) {
        return objectExists(objectName)
            && Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().containsKey(fieldName);
    }

    private static void putIfPresent(SObject record, String fieldName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    private static String relatedName(SObject record, String relationshipName) {
        SObject related = record.getSObject(relationshipName);
        if (related == null) {
            return null;
        }
        String firstName = asString(getIfPresent(related, 'First_Name__c'));
        String lastName = asString(getIfPresent(related, 'Last_Name__c'));
        List<String> parts = new List<String>();
        if (!String.isBlank(firstName)) {
            parts.add(firstName);
        }
        if (!String.isBlank(lastName)) {
            parts.add(lastName);
        }
        String fullName = String.join(parts, ' ').trim();
        return String.isBlank(fullName) ? asString(getIfPresent(related, 'Name')) : fullName;
    }

    private static String relatedField(SObject record, String relationshipName, String fieldName) {
        SObject related = record.getSObject(relationshipName);
        return related == null ? null : asString(getIfPresent(related, fieldName));
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Decimal asDecimal(Object value) {
        return value == null ? null : Decimal.valueOf(String.valueOf(value));
    }

    private static Boolean asBoolean(Object value) {
        return value == null ? false : Boolean.valueOf(value);
    }

    public class PipelineStage {
        @AuraEnabled public String name;
        @AuraEnabled public List<PipelineCard> applications = new List<PipelineCard>();

        public PipelineStage(String name) {
            this.name = name;
        }
    }

    public class PipelineCard {
        @AuraEnabled public Id id;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String positionName;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal matchScore;
        @AuraEnabled public Date appliedDate;
        @AuraEnabled public Decimal daysInStage;
        @AuraEnabled public Boolean slaBreached;
        @AuraEnabled public String priority;
    }

    public class TimelinePayload {
        @AuraEnabled public ApplicationSummary application;
        @AuraEnabled public List<InterviewItem> interviews = new List<InterviewItem>();
        @AuraEnabled public List<StageItem> stages = new List<StageItem>();
        @AuraEnabled public List<ScoreTrendPoint> scoreTrend = new List<ScoreTrendPoint>();
        @AuraEnabled public List<MatchDetail> matchDetails = new List<MatchDetail>();
        @AuraEnabled public List<StatusOption> statusOptions = new List<StatusOption>();
    }

    public class ApplicationSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public Id positionId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String positionName;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal matchScore;
        @AuraEnabled public Decimal daysInStage;
        @AuraEnabled public Decimal slaDaysRemaining;
        @AuraEnabled public Boolean slaBreached;
    }

    public class InterviewItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String type;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime dateTimeValue;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String interviewerName;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String feedback;
        @AuraEnabled public FeedbackItem feedbackDetails;
    }

    public class StageItem {
        @AuraEnabled public Integer numberValue;
        @AuraEnabled public String type;
        @AuraEnabled public String state;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime dateTimeValue;
        @AuraEnabled public Decimal score;
        @AuraEnabled public InterviewItem interview;
    }

    public class FeedbackItem {
        @AuraEnabled public Id id;
        @AuraEnabled public Decimal technicalScore;
        @AuraEnabled public Decimal communicationScore;
        @AuraEnabled public Decimal cultureFitScore;
        @AuraEnabled public Decimal compositeScore;
        @AuraEnabled public String strengths;
        @AuraEnabled public String weaknesses;
        @AuraEnabled public String comments;
        @AuraEnabled public String recommendation;
    }

    public class ScoreTrendPoint {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal score;
    }

    public class MatchDetail {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal value;
        @AuraEnabled public Decimal weightedValue;
    }

    public class StatusOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class MessageItem {
        @AuraEnabled public Id id;
        @AuraEnabled public Id applicationId;
        @AuraEnabled public String body;
        @AuraEnabled public String direction;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
    }
}
