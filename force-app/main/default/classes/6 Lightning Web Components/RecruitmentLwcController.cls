public with sharing class RecruitmentLwcController {
    private static final String APPLICATION_OBJECT = 'Application__c';
    private static final String INTERVIEW_OBJECT = 'Interview__c';
    private static final String FEEDBACK_OBJECT = 'Interview_Feedback__c';
    private static final String MESSAGE_OBJECT = 'Message__c';
    private static final String MESSAGE_EVENT = 'Recruitment_Message__e';
    private static final String PIPELINE_EVENT = 'Application_Pipeline_Update__e';

    @AuraEnabled
    public static List<PipelineStage> getPipelineBoard() {
        List<String> statuses = getApplicationStatuses();
        Map<String, PipelineStage> stagesByStatus = new Map<String, PipelineStage>();
        for (String status : statuses) {
            stagesByStatus.put(status, new PipelineStage(status));
        }

        if (!objectExists(APPLICATION_OBJECT)) {
            return stagesByStatus.values();
        }

        String query = buildApplicationQuery();
        System.debug('Query: ' + query);
        List<SObject> apps = Database.query(query);
        System.debug('Total apps fetched: ' + apps.size());
        
        for (SObject app : apps) {
            String status = asString(getIfPresent(app, 'Status__c'));
            if (String.isBlank(status)) {
                status = 'New';
            }
            System.debug('Processing app with status: ' + status);
            if (!stagesByStatus.containsKey(status)) {
                stagesByStatus.put(status, new PipelineStage(status));
            }
            PipelineCard card = toPipelineCard(app);
            System.debug('Card created: ' + card.candidateName + ' | Score: ' + card.matchScore);
            stagesByStatus.get(status).applications.add(card);
        }

        System.debug('Final stages: ' + stagesByStatus.keySet());
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

        if (objectExists(INTERVIEW_OBJECT)) {
            for (SObject interview : Database.query(buildInterviewQuery(applicationId))) {
                payload.interviews.add(toInterviewItem(interview));
            }
        }

        payload.stages = buildStageItemsWithRules(payload.interviews);
        payload.scoreTrend = buildScoreTrend(payload.stages);
        payload.matchDetails = buildMatchDetails(applicationId, app);
        
        return payload;
    }

    private static List<StageItem> buildStageItemsWithRules(List<InterviewItem> interviews) {
        List<String> stageTypes = new List<String>{'Phone Screen', 'Technical', 'HR/Behavioral', 'Cultural Fit', 'Final/Executive'};
        List<StageItem> stages = new List<StageItem>();
        Map<String, InterviewItem> interviewMap = new Map<String, InterviewItem>();
        for (InterviewItem iv : interviews) {
            interviewMap.put(iv.type, iv);
        }

        Boolean phoneCompleted = isStageCompleted(interviewMap, 'Phone Screen');
        Boolean techCompleted = isStageCompleted(interviewMap, 'Technical');
        Boolean hrCompleted = isStageCompleted(interviewMap, 'HR/Behavioral');
        Boolean cultureCompleted = isStageCompleted(interviewMap, 'Cultural Fit');
        Boolean finalCompleted = isStageCompleted(interviewMap, 'Final/Executive');

        for (Integer i = 0; i < stageTypes.size(); i++) {
            String type = stageTypes[i];
            InterviewItem iv = interviewMap.get(type);
            StageItem stage = new StageItem();
            stage.numberValue = i + 1;
            stage.type = type;
            stage.interview = iv;

            if (i == 0) { // Phone Screen
                stage.state = phoneCompleted ? 'completed' : (iv != null ? 'active' : 'available');
            } 
            else if (i >= 1 && i <= 3) { // 2,3,4
                if (!phoneCompleted) {
                    stage.state = 'pending';
                } else if (iv != null && iv.status == 'Completed') {
                    stage.state = 'completed';
                } else {
                    stage.state = 'available';
                }
            } 
            else if (i == 4) { // Final
                if ((techCompleted && hrCompleted && cultureCompleted) || (iv != null && iv.status != 'Cancelled')) {
                    stage.state = (iv != null && iv.status == 'Completed') ? 'completed' : 'available';
                } else {
                    stage.state = 'pending';
                }
            }

            if (iv != null) {
                stage.status = iv.status;
                stage.dateTimeValue = iv.dateTimeValue;
                stage.score = iv.score;
                if (iv.status == 'Completed') {
                    stage.state = 'completed';
                } else if (iv.status == 'Cancelled' || iv.status == 'No Show') {
                    stage.state = 'rejected';
                }
            } else {
                stage.status = (stage.state == 'pending' ? 'Pending' : (stage.state == 'available' ? 'Available' : 'Active'));
            }
            stages.add(stage);
        }
        return stages;
    }

    private static Boolean isStageCompleted(Map<String, InterviewItem> interviewMap, String type) {
        InterviewItem iv = interviewMap.get(type);
        return iv != null && iv.status == 'Completed';
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

        Datetime startTime = nextAvailableSlot(UserInfo.getUserId());
        return InterviewService.scheduleInterview(applicationId, UserInfo.getUserId(), startTime, nextType);
    }

    @AuraEnabled
    public static void finalizeApplication(Id applicationId, String decision, String rejectionReason) {
        System.debug('=== finalizeApplication called ===');
        System.debug('appId: ' + applicationId + ', decision: ' + decision + ', reason: ' + rejectionReason);
        
        if (applicationId == null || String.isBlank(decision)) {
            throw new AuraHandledException('Application ID and decision are required.');
        }
        
        Application__c app = [SELECT Id, Status__c FROM Application__c WHERE Id = :applicationId LIMIT 1];
        
        String newStatus;
        if (decision == 'Hire') {
            newStatus = 'Hired';
        } else if (decision == 'Reject') {
            newStatus = 'Rejected';
        } else if (decision == 'Withdrawn') {
            newStatus = 'Withdrawn';
        } else {
            throw new AuraHandledException('Invalid decision. Must be Hire, Reject, or Withdrawn.');
        }
        
        app.Status__c = newStatus;
        
        if (decision == 'Reject' && String.isNotBlank(rejectionReason)) {
            if (fieldExists(APPLICATION_OBJECT, 'Rejection_Reason__c')) {
                app.Rejection_Reason__c = rejectionReason;
            } else if (fieldExists(APPLICATION_OBJECT, 'Reason_for_Rejection__c')) {
                app.Reason_for_Rejection__c = rejectionReason;
            }
        }
        
        
        Database.SaveResult result = Database.update(app, false);
        if (!result.isSuccess()) {
            String errorMsg = '';
            for (Database.Error err : result.getErrors()) {
                errorMsg += err.getMessage() + ' ';
            }
            throw new AuraHandledException('Update failed: ' + errorMsg);
        }
        
        publishPipelineEvent(applicationId, newStatus);
        System.debug('Status updated to: ' + newStatus);
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
    public static MessageItem sendMessage(Id applicationId, String body, String channel) {
        if (applicationId == null || String.isBlank(body)) {
            throw new AuraHandledException('Application and message body are required.');
        }

        MessageItem item = new MessageItem();
        item.applicationId = applicationId;
        item.body = body.trim();
        item.channel = normalizeMessageChannel(channel);
        item.direction = 'Outbound';
        item.createdDate = System.now();
        item.createdByName = UserInfo.getName();
        item.senderName = UserInfo.getName();
        item.isRead = true;

        if (objectExists(MESSAGE_OBJECT)) {
            SObject message = Schema.getGlobalDescribe().get(MESSAGE_OBJECT).newSObject();
            putIfPresent(message, 'Related_Record_Id__c', String.valueOf(applicationId));
            putIfPresent(message, 'Application__c', applicationId);
            putIfPresent(message, 'Body__c', item.body);
            putIfPresent(message, 'Subject__c', 'Recruitment message');
            putIfPresent(message, 'Direction__c', item.direction);
            putIfPresent(message, 'Channel__c', item.channel);
            putIfPresent(message, 'Sender__c', UserInfo.getUserId());
            putIfPresent(message, 'Sent_At__c', item.createdDate);
            putIfPresent(message, 'Is_Read__c', true);
            putIfPresent(message, 'Status__c', 'Sent');
            insert message;
            item.id = (Id) message.get('Id');
        }

        publishMessageEvent(item);
        NotificationService.sendStatusUpdate(applicationId, 'Message sent via ' + item.channel);
        return item;
    }

    @AuraEnabled(cacheable=true)
    public static List<ChatterItem> getChatterPosts(Id applicationId) {
        List<ChatterItem> posts = new List<ChatterItem>();
        if (applicationId == null) {
            return posts;
        }
        for (FeedItem item : [
            SELECT Id, Body, CreatedDate, CreatedBy.Name
            FROM FeedItem
            WHERE ParentId = :applicationId
            ORDER BY CreatedDate DESC
            LIMIT 20
        ]) {
            ChatterItem post = new ChatterItem();
            post.id = item.Id;
            post.body = item.Body;
            post.createdDate = item.CreatedDate;
            post.createdByName = item.CreatedBy.Name;
            posts.add(post);
        }
        return posts;
    }

    @AuraEnabled
    public static ChatterItem postToChatter(Id applicationId, String body) {
        if (applicationId == null || String.isBlank(body)) {
            throw new AuraHandledException('Application and Chatter body are required.');
        }
        FeedItem post = new FeedItem(
            ParentId = applicationId,
            Body = body.trim()
        );
        insert post;

        post = [
            SELECT Id, Body, CreatedDate, CreatedBy.Name
            FROM FeedItem
            WHERE Id = :post.Id
            LIMIT 1
        ];

        ChatterItem item = new ChatterItem();
        item.id = post.Id;
        item.body = post.Body;
        item.createdDate = post.CreatedDate;
        item.createdByName = post.CreatedBy.Name;
        return item;
    }

    @AuraEnabled
    public static Integer markAllMessagesRead(Id applicationId) {
        if (applicationId == null || !objectExists(MESSAGE_OBJECT) || !fieldExists(MESSAGE_OBJECT, 'Is_Read__c')) {
            return 0;
        }
        List<SObject> unread = Database.query(
            'SELECT Id, Is_Read__c FROM Message__c WHERE Application__c = \'' +
            String.escapeSingleQuotes(String.valueOf(applicationId)) + '\' AND Is_Read__c = false'
        );
        for (SObject message : unread) {
            message.put('Is_Read__c', true);
        }
        if (!unread.isEmpty()) {
            update unread;
        }
        return unread.size();
    }

    @AuraEnabled
    public static void publishTypingIndicator(Id applicationId, Boolean isTyping) {
        if (applicationId == null || !objectExists(MESSAGE_EVENT)) {
            return;
        }
        SObject eventRecord = Schema.getGlobalDescribe().get(MESSAGE_EVENT).newSObject();
        putIfPresent(eventRecord, 'Application_Id__c', String.valueOf(applicationId));
        putIfPresent(eventRecord, 'Direction__c', 'Outbound');
        putIfPresent(eventRecord, 'Sender_Name__c', UserInfo.getName());
        putIfPresent(eventRecord, 'Is_Typing__c', isTyping == true);
        EventBus.publish(eventRecord);
    }

    @AuraEnabled
    public static FilterOptions getFilterOptions() {
        FilterOptions options = new FilterOptions();

        try {
            if (!objectExists(APPLICATION_OBJECT)) {
                return options;
            }

            Boolean hasDept = fieldExists(APPLICATION_OBJECT, 'Department__c');
            List<String> fields = new List<String>{ 'Id', 'Position__r.Name', 'Recruiter__r.Name' };
            if (hasDept) {
                fields.add('Department__c');
            }

            List<SObject> allApps = Database.query(
                'SELECT ' + String.join(fields, ', ') + ' FROM Application__c LIMIT 1000'
            );

            Set<String> deptSeen = new Set<String>();
            Set<String> recruiterSeen = new Set<String>();
            Set<String> positionSeen = new Set<String>();

            for (SObject app : allApps) {
                if (hasDept) {
                    String dept = (String) app.get('Department__c');
                    if (String.isNotBlank(dept) && deptSeen.add(dept)) {
                        options.departments.add(new FilterOption(dept, dept));
                    }
                }

                String position = relatedName(app, 'Position__r');
                if (String.isNotBlank(position) && positionSeen.add(position)) {
                    options.positions.add(new FilterOption(position, position));
                }

                String recruiter = relatedName(app, 'Recruiter__r');
                if (String.isNotBlank(recruiter) && recruiterSeen.add(recruiter)) {
                    options.recruiters.add(new FilterOption(recruiter, recruiter));
                }
            }
        } catch (Exception e) {
            System.debug('Error in getFilterOptions: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return options;
    }

    @AuraEnabled
    public static void bulkUpdateApplications(List<Id> applicationIds, String action) {
        if (applicationIds == null || applicationIds.isEmpty() || String.isBlank(action)) {
            throw new AuraHandledException('Applications and action are required.');
        }

        List<Application__c> appsToUpdate = new List<Application__c>();
        String targetStatus = action.equals('reject') ? 'Rejected' : 'Interview 1';

        List<Application__c> existingApps = [
            SELECT Id, Status__c
            FROM Application__c
            WHERE Id IN :applicationIds
        ];

        for (Application__c app : existingApps) {
            app.Status__c = targetStatus;
            if (fieldExists(APPLICATION_OBJECT, 'Last_Stage_Change_Date__c')) {
                app.Last_Stage_Change_Date__c = Date.today();
            }
            appsToUpdate.add(app);
        }

        if (appsToUpdate.isEmpty()) {
            throw new AuraHandledException('No applications can be updated due to invalid status transitions.');
        }

        try {
            update appsToUpdate;
            if (objectExists(PIPELINE_EVENT)) {
                SObject eventRecord = Schema.getGlobalDescribe().get(PIPELINE_EVENT).newSObject();
                putIfPresent(eventRecord, 'Application_Id__c', null);
                putIfPresent(eventRecord, 'Status__c', 'Bulk ' + action);
                EventBus.publish(eventRecord);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Database error: ' + e.getMessage());
        }
    }

    // МЕТОДЫ ДЛЯ РАСПИСАНИЯ ИНТЕРВЬЮ
    @AuraEnabled
    public static DateTime getNearestAvailableSlot(Id applicationId) {
        if (applicationId == null) {
            throw new AuraHandledException('Application ID is required.');
        }

        String stageType = getActiveInterviewStage(applicationId);
        if (String.isBlank(stageType)) {
            throw new AuraHandledException('No active interview stage found for this application.');
        }

        Id interviewerId = getDefaultInterviewerId(applicationId);
        if (interviewerId == null) {
            interviewerId = UserInfo.getUserId();
        }

        Datetime searchStart = System.now().addHours(2);
        Datetime searchEnd = searchStart.addDays(30);
        Set<Datetime> occupied = new Set<Datetime>();
        for (Interview__c interview : [
            SELECT Date_Time__c
            FROM Interview__c
            WHERE Interviewer__c = :interviewerId
              AND Date_Time__c >= :searchStart
              AND Date_Time__c <= :searchEnd
              AND Status__c NOT IN ('Cancelled', 'No Show')
        ]) {
            if (interview.Date_Time__c != null) occupied.add(interview.Date_Time__c);
        }

        for (Integer dayOffset = 0; dayOffset < 30; dayOffset++) {
            Date currentDate = searchStart.date().addDays(dayOffset);
            if (isWeekend(currentDate)) continue;

            for (Integer hour = 9; hour <= 17; hour++) {
                Datetime slot = Datetime.newInstance(currentDate, Time.newInstance(hour, 0, 0, 0));
                if (slot < searchStart) continue;
                if (occupied.contains(slot)) continue;
                return slot;
            }
        }
        throw new AuraHandledException('No available interview slots found in the next 30 days.');
    }

        @AuraEnabled
        public static void scheduleInterviewAtSlot(Id applicationId, DateTime selectedTime, String interviewType) {
            if (applicationId == null || selectedTime == null || String.isBlank(interviewType)) {
        throw new AuraHandledException('Application ID, time, and interview type are required.');
    }
        Id interviewerId = getDefaultInterviewerId(applicationId);
        if (interviewerId == null) interviewerId = UserInfo.getUserId();
            Interview__c newInterview = new Interview__c();
            newInterview.Application__c = applicationId;
            newInterview.Type__c = interviewType;
            newInterview.Status__c = 'Scheduled';
            newInterview.Date_Time__c = selectedTime;
            newInterview.Interviewer__c = interviewerId;
            insert newInterview;
}

    private static String getActiveInterviewStage(Id applicationId) {
        List<Interview__c> interviews = [
            SELECT Type__c, Status__c
            FROM Interview__c
            WHERE Application__c = :applicationId
            ORDER BY CreatedDate ASC
        ];
        Set<String> completedTypes = new Set<String>();
        for (Interview__c iv : interviews) {
            if (iv.Status__c == 'Completed') {
                completedTypes.add(iv.Type__c);
            }
        }
        List<String> allStages = new List<String>{ 'Phone Screen', 'Technical', 'HR/Behavioral', 'Cultural Fit', 'Final/Executive' };
        for (String stage : allStages) {
            if (!completedTypes.contains(stage)) {
                return stage;
            }
        }
        return null;
    }

    private static Id getDefaultInterviewerId(Id applicationId) {
        try {
            Application__c app = [
                SELECT Recruiter__c
                FROM Application__c
                WHERE Id = :applicationId
                LIMIT 1
            ];
            return app.Recruiter__c;
        } catch (Exception e) {
            return UserInfo.getUserId();
        }
    }

    private static Boolean isWeekend(Date dt) {
        DateTime dtTime = DateTime.newInstance(dt, Time.newInstance(0, 0, 0, 0));
        String dayOfWeek = dtTime.format('E');
        return dayOfWeek == 'Sat' || dayOfWeek == 'Sun';
    }

    // ================= ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ =================
    private static PipelineCard toPipelineCard(SObject app) {
        PipelineCard card = new PipelineCard();
        card.id = (Id) app.get('Id');
        card.candidateId = (Id) getIfPresent(app, 'Candidate__c');
        card.positionId = (Id) getIfPresent(app, 'Position__c');
        card.status = asString(getIfPresent(app, 'Status__c'));
        card.candidateName = relatedName(app, 'Candidate__r');
        card.positionName = relatedName(app, 'Position__r');
        card.matchScore = asDecimal(getIfPresent(app, 'Match_Score__c'));
        card.appliedDate = (Date) getIfPresent(app, 'Applied_Date__c');
        card.daysInStage = asDecimal(getIfPresent(app, 'Days_in_Stage__c'));
        card.slaBreached = asBoolean(getIfPresent(app, 'SLA_Breach__c'));
        card.slaAtRisk = (card.daysInStage != null && card.daysInStage >= 5 && !card.slaBreached);
        card.priority = relatedField(app, 'Position__r', 'Priority__c');
        card.department = asString(getIfPresent(app, 'Department__c'));
        card.recruiter = relatedName(app, 'Recruiter__r');
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
        if (value == null) return;
        MatchDetail detail = new MatchDetail();
        detail.label = label;
        detail.value = value;
        detail.weightedValue = weightedValue;
        details.add(detail);
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
        if (interviewId == null || !objectExists(FEEDBACK_OBJECT)) return null;
        List<SObject> feedbackRecords = Database.query(buildFeedbackQuery(interviewId));
        if (feedbackRecords.isEmpty()) return null;
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
        item.channel = asString(getIfPresent(message, 'Channel__c'));
        item.isRead = asBoolean(getIfPresent(message, 'Is_Read__c'));
        item.createdDate = (Datetime) getFirstPresent(message, new List<String>{ 'Sent_At__c', 'CreatedDate' });
        item.senderName = relatedName(message, 'Sender__r');
        item.createdByName = relatedName(message, 'CreatedBy');
        return item;
    }

    private static String buildApplicationQuery() {
        List<String> fields = new List<String>{ 'Id', 'Status__c', 'Candidate__c', 'Position__c' };
        addField(fields, APPLICATION_OBJECT, 'Applied_Date__c');
        addField(fields, APPLICATION_OBJECT, 'Match_Score__c');
        addField(fields, APPLICATION_OBJECT, 'Days_in_Stage__c');
        addField(fields, APPLICATION_OBJECT, 'SLA_Breach__c');
        addField(fields, APPLICATION_OBJECT, 'Department__c');
        fields.add('Candidate__r.Name');
        addRelationshipField(fields, 'Candidate__r', 'First_Name__c');
        addRelationshipField(fields, 'Candidate__r', 'Last_Name__c');
        fields.add('Position__r.Name');
        addRelationshipField(fields, 'Position__r', 'Priority__c');
        fields.add('Recruiter__r.Name');
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
        addField(fields, MESSAGE_OBJECT, 'Channel__c');
        addField(fields, MESSAGE_OBJECT, 'Is_Read__c');
        addField(fields, MESSAGE_OBJECT, 'Sent_At__c');
        fields.add('Sender__r.Name');

        String whereClause = fieldExists(MESSAGE_OBJECT, 'Application__c')
            ? 'Application__c = \'' + String.escapeSingleQuotes(String.valueOf(applicationId)) + '\''
            : 'Related_Record_Id__c = \'' + String.escapeSingleQuotes(String.valueOf(applicationId)) + '\'';

        return 'SELECT ' + String.join(fields, ',')
            + ' FROM Message__c WHERE ' + whereClause + ' ORDER BY CreatedDate ASC LIMIT 200';
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

    private static String normalizeMessageChannel(String channel) {
        String value = String.isBlank(channel) ? 'Portal' : channel;
        Set<String> allowed = new Set<String>{ 'Email', 'Portal' };
        return allowed.contains(value) ? value : 'Portal';
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
        if (!objectExists(MESSAGE_EVENT)) return;
        SObject eventRecord = Schema.getGlobalDescribe().get(MESSAGE_EVENT).newSObject();
        putIfPresent(eventRecord, 'Application_Id__c', String.valueOf(item.applicationId));
        putIfPresent(eventRecord, 'Message_Body__c', item.body);
        putIfPresent(eventRecord, 'Direction__c', item.direction);
        putIfPresent(eventRecord, 'Channel__c', item.channel);
        putIfPresent(eventRecord, 'Sender_Name__c', item.senderName);
        putIfPresent(eventRecord, 'Is_Typing__c', false);
        EventBus.publish(eventRecord);
    }

    private static void publishPipelineEvent(Id applicationId, String status) {
        if (!objectExists(PIPELINE_EVENT)) return;
        SObject eventRecord = Schema.getGlobalDescribe().get(PIPELINE_EVENT).newSObject();
        putIfPresent(eventRecord, 'Application_Id__c', String.valueOf(applicationId));
        putIfPresent(eventRecord, 'Status__c', status);
        EventBus.publish(eventRecord);
    }

    private static void addField(List<String> fields, String objectName, String fieldName) {
        if (fieldExists(objectName, fieldName)) fields.add(fieldName);
    }

    private static void addRelationshipField(List<String> fields, String relationshipName, String fieldName) {
        fields.add(relationshipName + '.' + fieldName);
    }

    private static Object getIfPresent(SObject record, String fieldName) {
        if (record == null || !record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) return null;
        try {
            return record.get(fieldName);
        } catch (SObjectException e) {
            return null;
        }
    }

    private static Object getFirstPresent(SObject record, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            Object value = getIfPresent(record, fieldName);
            if (value != null) return value;
        }
        return null;
    }

    private static Datetime nextAvailableSlot(Id interviewerId) {
        Datetime searchStart = System.now();
        Datetime searchEnd = searchStart.addDays(30);
        Set<Datetime> occupied = new Set<Datetime>();
        for (Interview__c interview : [
            SELECT Date_Time__c
            FROM Interview__c
            WHERE Interviewer__c = :interviewerId
            AND Date_Time__c >= :searchStart
            AND Date_Time__c <= :searchEnd
            AND Status__c NOT IN ('Cancelled', 'No Show')
        ]) {
            occupied.add(interview.Date_Time__c);
        }

        Date candidateDate = searchStart.date().addDays(1);
        for (Integer dayOffset = 0; dayOffset < 30; dayOffset++) {
            Date currentDate = candidateDate.addDays(dayOffset);
            for (Integer hour = 10; hour <= 17; hour++) {
                Datetime slot = Datetime.newInstance(currentDate, Time.newInstance(hour, 0, 0, 0));
                if ((slot.format('E') == 'Sat' || slot.format('E') == 'Sun') || occupied.contains(slot)) {
                    continue;
                }
                return slot;
            }
        }
        throw new AuraHandledException('No available interview slots found for the next 30 days.');
    }

    private static Boolean objectExists(String objectName) {
        return Schema.getGlobalDescribe().containsKey(objectName);
    }

    private static Boolean fieldExists(String objectName, String fieldName) {
        return objectExists(objectName) && Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().containsKey(fieldName);
    }

    private static void putIfPresent(SObject record, String fieldName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    private static String relatedName(SObject record, String relationshipName) {
        SObject related = record.getSObject(relationshipName);
        if (related == null) return null;
        String firstName = asString(getIfPresent(related, 'First_Name__c'));
        String lastName = asString(getIfPresent(related, 'Last_Name__c'));
        List<String> parts = new List<String>();
        if (!String.isBlank(firstName)) parts.add(firstName);
        if (!String.isBlank(lastName)) parts.add(lastName);
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

    // ================= ВНУТРЕННИЕ КЛАССЫ =================
    public class PipelineStage {
        @AuraEnabled public String name;
        @AuraEnabled public List<PipelineCard> applications = new List<PipelineCard>();
        public PipelineStage(String name) { this.name = name; }
    }

    public class PipelineCard {
        @AuraEnabled public Id id;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public Id positionId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String positionName;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal matchScore;
        @AuraEnabled public Date appliedDate;
        @AuraEnabled public Decimal daysInStage;
        @AuraEnabled public Boolean slaBreached;
        @AuraEnabled public Boolean slaAtRisk;
        @AuraEnabled public String priority;
        @AuraEnabled public String department;
        @AuraEnabled public String recruiter;
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
        @AuraEnabled public String channel;
        @AuraEnabled public Boolean isRead;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String senderName;
        @AuraEnabled public String createdByName;
    }

    public class FilterOptions {
        @AuraEnabled public List<FilterOption> departments = new List<FilterOption>();
        @AuraEnabled public List<FilterOption> recruiters = new List<FilterOption>();
        @AuraEnabled public List<FilterOption> positions = new List<FilterOption>();
    }

    public class FilterOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public FilterOption(String value, String label) { this.value = value; this.label = label; }
    }

    public class ChatterItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String body;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
    }
}