function testAccount(accountName) {
    $.get("/test_account/" + accountName, function(data) {
        $("#zoneMessage").html(data);
    });
}