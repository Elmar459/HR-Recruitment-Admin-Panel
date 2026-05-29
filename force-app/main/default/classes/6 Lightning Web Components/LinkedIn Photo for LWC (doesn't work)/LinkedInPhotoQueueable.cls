// LinkedInPhotoQueueable.cls
public class LinkedInPhotoQueueable implements Queueable {
    private List<Candidate__c> candidates;
    
    public LinkedInPhotoQueueable(List<Candidate__c> candidates) {
        this.candidates = candidates;
    }
    
    public void execute(QueueableContext ctx) {
        for (Candidate__c cand : candidates) {
            LinkedInPhotoService.fetchAndAttachPhoto(cand.Id, cand.LinkedIn_URL__c);
        }
    }
}