@isTest
public class STO_GroupSkillSyncScheduler_Test {
    @isTest
    static void testGroupSkillSyncSched() {
        STO_GroupSkillSyncScheduler scheduler = new STO_GroupSkillSyncScheduler();
        scheduler.execute(null);
    }
}
