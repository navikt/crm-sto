public with sharing class STO_GroupSkillSyncScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        STO_GroupMemberSkillService service = new STO_GroupMemberSkillService();
        service.handleGroupAndSkillSync();
    }
}
