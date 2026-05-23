public with sharing class ChatterService {

    /*
     * Generic method for posting to Chatter Feed
     */
    public static void postToRecord(Id recordId, String message) {

        if(recordId == null || String.isBlank(message)){
            return;
        }

        FeedItem post = new FeedItem();

        post.ParentId = recordId;
        post.Body = message;

        insert post;
    }

    /*
     * Application Created
     */
    public static void postApplicationCreated(List<Application__c> applications){

        List<FeedItem> posts = new List<FeedItem>();

        for(Application__c app : applications){

            String message =
                '📄 New application received.\n' +
                'Status: ' + app.Status__c + '\n' +
                'Match Score: ' + String.valueOf(app.Match_Score__c);

            FeedItem post = new FeedItem();

            post.ParentId = app.Id;
            post.Body = message;

            posts.add(post);
        }

        if(!posts.isEmpty()){
            insert posts;
        }
    }

    /*
     * Status Changed
     */
    public static void postStatusChanged(
        Map<Id, Application__c> oldMap,
        List<Application__c> newList
    ){

        List<FeedItem> posts = new List<FeedItem>();

        for(Application__c newApp : newList){

            Application__c oldApp = oldMap.get(newApp.Id);

            if(oldApp.Status__c != newApp.Status__c){

                String message =
                    '🔄 Application status changed.\n' +
                    'Old Status: ' + oldApp.Status__c + '\n' +
                    'New Status: ' + newApp.Status__c;

                FeedItem post = new FeedItem();

                post.ParentId = newApp.Id;
                post.Body = message;

                posts.add(post);
            }
        }

        if(!posts.isEmpty()){
            insert posts;
        }
    }

    /*
     * Interview Completed
     */
    public static void postInterviewCompleted(
        List<Interview__c> newList,
        Map<Id, Interview__c> oldMap
    ){

        List<FeedItem> posts = new List<FeedItem>();

        for(Interview__c interview : newList){

            Interview__c oldInterview = oldMap.get(interview.Id);

            if(
                oldInterview.Status__c != 'Completed' &&
                interview.Status__c == 'Completed'
            ){

                String message =
                    '✅ Interview completed.\n' +
                    'Type: ' + interview.Type__c + '\n' +
                    'Interview Number: ' + String.valueOf(interview.Interview_Number__c);

                FeedItem post = new FeedItem();

                post.ParentId = interview.Application__c;
                post.Body = message;

                posts.add(post);
            }
        }

        if(!posts.isEmpty()){
            insert posts;
        }
    }

    /*
     * SLA Breach Alert
     */
    public static void postSLABreach(List<Application__c> applications){

        List<FeedItem> posts = new List<FeedItem>();

        for(Application__c app : applications){

            String message =
                '🚨 SLA BREACH ALERT\n' +
                'Application exceeded SLA threshold.\n' +
                'Current Status: ' + app.Status__c;

            FeedItem post = new FeedItem();

            post.ParentId = app.Id;
            post.Body = message;

            posts.add(post);
        }

        if(!posts.isEmpty()){
            insert posts;
        }
    }
}