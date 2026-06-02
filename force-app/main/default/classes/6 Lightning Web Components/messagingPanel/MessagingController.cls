public with sharing class MessagingController {
    
    @AuraEnabled(cacheable=true)
    public static List<MessageItem> getMessages(Id applicationId) {
        List<MessageItem> result = new List<MessageItem>();
        if (applicationId == null) return result;
        for (Message__c msg : [
            SELECT Id, Body__c, Direction__c, Channel__c, Is_Read__c,
                   Sent_At__c, Sender__r.Name, CreatedBy.Name, CreatedDate
            FROM Message__c
            WHERE Application__c = :applicationId
            ORDER BY CreatedDate ASC
            LIMIT 200
        ]) {
            MessageItem item = new MessageItem();
            item.id = msg.Id;
            item.body = msg.Body__c;
            item.direction = msg.Direction__c;
            item.channel = msg.Channel__c;
            item.isRead = msg.Is_Read__c;
            item.createdDate = msg.Sent_At__c != null ? msg.Sent_At__c : msg.CreatedDate;
            item.senderName = msg.Sender__r != null ? msg.Sender__r.Name : msg.CreatedBy.Name;
            item.createdByName = msg.CreatedBy.Name;
            item.applicationId = applicationId;
            result.add(item);
        }
        return result;
    }
    
    @AuraEnabled
    public static MessageItem sendMessage(Id applicationId, String body, String channel) {
        if (applicationId == null || String.isBlank(body)) {
            throw new AuraHandledException('Application ID and message body are required.');
        }
        try {
            String normalizedChannel = (channel == 'Email') ? 'Email' : 'Portal';
            Message__c msg = new Message__c();
            msg.Application__c = applicationId;
            msg.Body__c = body;
            msg.Direction__c = 'Outbound';
            msg.Channel__c = normalizedChannel;
            msg.Is_Read__c = true;
            msg.Sent_At__c = Datetime.now();
            msg.Sender__c = UserInfo.getUserId();
            // Автоматически заполняем Subject, если поле требуется (ищем стандартное имя)
            SObjectType messageType = Message__c.getSObjectType();
            Map<String, SObjectField> fields = messageType.getDescribe().fields.getMap();
            if (fields.containsKey('Subject')) {
                msg.put('Subject', 'Recruitment Message');
            } else if (fields.containsKey('Subject__c')) {
                msg.put('Subject__c', 'Recruitment Message');
            } else if (fields.containsKey('Name')) {
                msg.put('Name', 'Recruitment Message');
            }
            insert msg;
            
            if (normalizedChannel == 'Email') {
                sendEmail(applicationId, body);
            }
            
            MessageItem result = new MessageItem();
            result.id = msg.Id;
            result.body = body;
            result.direction = 'Outbound';
            result.channel = normalizedChannel;
            result.isRead = true;
            result.createdDate = msg.Sent_At__c;
            result.senderName = UserInfo.getName();
            result.createdByName = UserInfo.getName();
            result.applicationId = applicationId;
            
            publishPlatformEvent(applicationId, body, 'Outbound', normalizedChannel, UserInfo.getName());
            return result;
        } catch (DmlException dmle) {
            String errorMsg = '';
            for (Integer i = 0; i < dmle.getNumDml(); i++) {
                errorMsg += dmle.getDmlMessage(i) + ' ';
            }
            throw new AuraHandledException('Database error: ' + errorMsg);
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    private static void sendEmail(Id applicationId, String body) {
        try {
            Application__c app = [SELECT Candidate__r.Email__c FROM Application__c WHERE Id = :applicationId LIMIT 1];
            String candidateEmail = app.Candidate__r.Email__c;
            if (String.isBlank(candidateEmail)) {
                throw new AuraHandledException('Candidate email is not set.');
            }
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ candidateEmail });
            mail.setSubject('New message from Recruitment System');
            mail.setPlainTextBody(body);
            mail.setSenderDisplayName('Recruitment System');
            // Если настроен Email Service для ответов, раскомментируйте строку ниже
            // mail.setReplyTo('recruitment@your-subdomain.sforce.com');
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            throw new AuraHandledException('Email error: ' + e.getMessage());
        }
    }
    
    private static void publishPlatformEvent(Id applicationId, String body, String direction, String channel, String senderName) {
        try {
            if (!Schema.getGlobalDescribe().containsKey('Recruitment_Message__e')) return;
            SObject evt = Schema.getGlobalDescribe().get('Recruitment_Message__e').newSObject();
            evt.put('Application_Id__c', String.valueOf(applicationId));
            evt.put('Message_Body__c', body);
            evt.put('Direction__c', direction);
            evt.put('Channel__c', channel);
            evt.put('Sender_Name__c', senderName);
            evt.put('Is_Typing__c', false);
            EventBus.publish(evt);
        } catch (Exception e) {
            System.debug('Failed to publish event: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ChatterPostItem> getChatterPosts(Id applicationId) {
        List<ChatterPostItem> posts = new List<ChatterPostItem>();
        if (applicationId == null) return posts;
        for (FeedItem feed : [
            SELECT Id, Body, CreatedDate, CreatedBy.Name
            FROM FeedItem
            WHERE ParentId = :applicationId AND Type = 'TextPost'
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            if (String.isNotBlank(feed.Body)) {
                ChatterPostItem item = new ChatterPostItem();
                item.id = feed.Id;
                item.body = feed.Body;
                item.createdDate = feed.CreatedDate;
                item.createdByName = feed.CreatedBy.Name;
                posts.add(item);
            }
        }
        return posts;
    }
    
    @AuraEnabled
    public static ChatterPostItem postToChatter(Id applicationId, String body) {
        if (applicationId == null || String.isBlank(body)) {
            throw new AuraHandledException('Application ID and post body are required.');
        }
        try {
            FeedItem feed = new FeedItem(ParentId = applicationId, Body = body, Type = 'TextPost');
            insert feed;
            ChatterPostItem result = new ChatterPostItem();
            result.id = feed.Id;
            result.body = body;
            result.createdDate = feed.CreatedDate;
            result.createdByName = UserInfo.getName();
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error posting to Chatter: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void markAllMessagesRead(Id applicationId) {
        if (applicationId == null) return;
        try {
            List<Message__c> unread = [SELECT Id FROM Message__c WHERE Application__c = :applicationId AND Is_Read__c = false];
            for (Message__c msg : unread) msg.Is_Read__c = true;
            update unread;
        } catch (Exception e) {
            throw new AuraHandledException('Error marking read: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void publishTypingIndicator(Id applicationId, Boolean isTyping) {
        // Опциональная функция, заглушка
        System.debug('Typing: ' + applicationId + ' = ' + isTyping);
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
    
    public class ChatterPostItem {
        @AuraEnabled public String id;
        @AuraEnabled public String body;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
    }
}