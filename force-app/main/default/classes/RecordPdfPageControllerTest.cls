@IsTest
private class RecordPdfPageControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'VF Test Account', Description = 'Test desc');
        insert acc;
    }

    @IsTest
    static void testValidRecord() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'VF Test Account' LIMIT 1];

        PageReference page = Page.RecordPdfPage;
        page.getParameters().put('id', acc.Id);
        page.getParameters().put('objectApiName', 'Account');
        Test.setCurrentPage(page);

        Test.startTest();
        RecordPdfPageController ctrl = new RecordPdfPageController();
        Test.stopTest();

        System.assertEquals('VF Test Account', ctrl.recordLabel, 'Record label should match Account Name.');
        System.assert(!ctrl.fieldRows.isEmpty(), 'Field rows should be populated.');
        System.assertNotEquals(null, ctrl.generatedDate, 'Generated date should be set.');
    }

    @IsTest
    static void testMissingParams() {
        PageReference page = Page.RecordPdfPage;
        Test.setCurrentPage(page);

        Test.startTest();
        RecordPdfPageController ctrl = new RecordPdfPageController();
        Test.stopTest();

        System.assertEquals('Invalid Parameters', ctrl.recordLabel);
        System.assert(ctrl.fieldRows.isEmpty());
    }

    @IsTest
    static void testUnknownObject() {
        PageReference page = Page.RecordPdfPage;
        page.getParameters().put('id', '001000000000001AAA');
        page.getParameters().put('objectApiName', 'NonExistentObject__c');
        Test.setCurrentPage(page);

        Test.startTest();
        RecordPdfPageController ctrl = new RecordPdfPageController();
        Test.stopTest();

        System.assert(ctrl.recordLabel.contains('Unknown Object'), 'Should report unknown object.');
    }

    @IsTest
    static void testRecordNotFound() {
        PageReference page = Page.RecordPdfPage;
        page.getParameters().put('id', '001000000000001AAA');
        page.getParameters().put('objectApiName', 'Account');
        Test.setCurrentPage(page);

        Test.startTest();
        RecordPdfPageController ctrl = new RecordPdfPageController();
        Test.stopTest();

        System.assertEquals('Record not found', ctrl.recordLabel);
    }
}
