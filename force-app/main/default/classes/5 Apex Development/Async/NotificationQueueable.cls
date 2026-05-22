public class NotificationQueueable implements Queueable {
    private Id applicationId;
    private String statusValue;

    public NotificationQueueable(Id applicationId, String statusValue) {
        this.applicationId = applicationId;
        this.statusValue = statusValue;
    }

    public void execute(QueueableContext context) {
        NotificationService.sendStatusUpdate(applicationId, statusValue);
    }
}
