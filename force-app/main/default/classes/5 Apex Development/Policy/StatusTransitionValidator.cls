public class StatusTransitionValidator {
    private static final Map<String, List<String>> ALLOWED = new Map<String, List<String>>{
        'New' => new List<String>{ 'Screening', 'Rejected' },
        'Screening' => new List<String>{ 'Interview 1', 'Rejected' },
        'Interview 1' => new List<String>{ 'Interview 2', 'Offer', 'Rejected' },
        'Interview 2' => new List<String>{ 'Interview 3', 'Offer', 'Rejected' },
        'Interview 3' => new List<String>{ 'Interview 4', 'Offer', 'Rejected' },
        'Interview 4' => new List<String>{ 'Interview 5', 'Offer', 'Rejected' },
        'Interview 5' => new List<String>{ 'Offer', 'Rejected' },
        'Offer' => new List<String>{ 'Hired', 'Rejected' },
        'Hired' => new List<String>(),
        'Rejected' => new List<String>()
    };

    @AuraEnabled(cacheable=true)
    public static Boolean validate(String oldStatus, String newStatus) {
        if (oldStatus == newStatus || String.isBlank(oldStatus)) {
            return true;
        }
        return ALLOWED.containsKey(oldStatus) && ALLOWED.get(oldStatus).contains(newStatus);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getNextAllowedStatuses(String currentStatus) {
        return ALLOWED.containsKey(currentStatus)
            ? new List<String>(ALLOWED.get(currentStatus))
            : new List<String>();
    }
}
