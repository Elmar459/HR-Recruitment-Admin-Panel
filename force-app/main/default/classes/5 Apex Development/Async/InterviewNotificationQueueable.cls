public class InterviewNotificationQueueable implements Queueable {
    private Id interviewId;
    private String actionName;

    public InterviewNotificationQueueable(Id interviewId, String actionName) {
        this.interviewId = interviewId;
        this.actionName = actionName;
    }

    public void execute(QueueableContext context) {
        if (actionName == 'Scheduled') {
            NotificationService.sendInterviewInvite(interviewId);
        } else {
            NotificationService.logMessage('Interview', interviewId, 'Interview ' + actionName + '.');
        }
    }
}
