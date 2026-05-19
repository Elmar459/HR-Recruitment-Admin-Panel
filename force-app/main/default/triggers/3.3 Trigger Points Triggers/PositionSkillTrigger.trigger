trigger PositionSkillTrigger on Position_Skill__c (

    after insert,
    after update,
    after delete

) {

    if(Trigger.isDelete) {

        PositionSkillTriggerHandler.handleDelete(
            Trigger.old
        );

    } else {

        PositionSkillTriggerHandler.handle(
            Trigger.new
        );
    }
}