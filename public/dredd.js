function testAccount(accountName) {
    $.get("/test_account/" + accountName, function(data) {
        $("#zoneMessage").html(data);
    });
}

var previousPoint = null;

function zeroPad(num, count)
{
    var numZeropad = num + '';
    while (numZeropad.length < count) {
        numZeropad = "0" + numZeropad;
    }
    return numZeropad;
}

function showTooltip(x, y, contents) {
    $('<div id="tooltip">' + contents + '</div>').css({
        position: 'absolute',
        display: 'none',
        top: y - 20,
        left: x + 5,
        border: '1px solid #fdd',
        padding: '2px',
        'background-color': '#fee',
        opacity: 0.80
    }).appendTo("body").fadeIn(200);
}

$(function () {
    $("#graph").bind("plothover", function (event, pos, item) {
        $("#x").text(pos.x.toFixed(2));
        $("#y").text(pos.y.toFixed(2));

        if (item) {
            if (previousPoint != item.datapoint) {
                previousPoint = item.datapoint;

                $("#tooltip").remove();
                var date = new Date(item.datapoint[0]);
                var toolTipString = zeroPad(date.getDate(), 2) + '/' + zeroPad(date.getMonth(), 2) + '/' + zeroPad(date.getFullYear(), 4) + ' ' + zeroPad(date.getHours(), 2) + ':' + zeroPad(date.getMinutes(), 2) + ':' + zeroPad(date.getSeconds(), 2) + " &rarr; " + item.datapoint[1] + "s";
                showTooltip(item.pageX, item.pageY,
                        toolTipString);
            }
        }
        else {
            $("#tooltip").remove();
            previousPoint = null;
        }
    });

    $("#graph").bind("plotclick", function (event, pos, item) {
        if (item) {
            $("#clickdata").text("You clicked point " + item.dataIndex + " in " + item.series.label + ".");
            plot.highlight(item.series, item.datapoint);
        }
    });
});