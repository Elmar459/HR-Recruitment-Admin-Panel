global with sharing class CandidateMatchBatchScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {

        CandidateMatchBatchJob batch = new CandidateMatchBatchJob();

        Database.executeBatch(batch, 50);
    }
}