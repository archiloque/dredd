function testAccount(accountName) {
    $.get("/test_account/" + accountName, function(data) {
        $("#zoneMessage").html(data);
    });
}

var previousPoint = null;


function zeroPad(num, count) {
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


function displayDateGeneral(date) {
    if (date == null) {
        minDisplayed = maxDisplayed = null;
        showPoints = false;
    } else {
        minDisplayed = date;
        maxDisplayed = date + (24 * 60 * 60 * 1000);
        showPoints = true;
    }
    plotGeneral();
}

function plotGeneral() {

    var data = [];

    var displayMaximum = $("input[name=Maximum]:checked").length == 1;

    if ($("input[name=Médiane]:checked").length == 1) {
        data.push(datasetMedian);
    }

    if (displayMaximum) {
        data.push(datasetMaximum);
    }

    $(".plotCheck").each(function () {
        var key = $(this).attr("name");
        if ((key != "Maximum") && (key != 'Médiane')) {
            if ($("input[name=" + key + "]:checked").length == 1) {
                data.push(dataset[key]);
            } else {
                var displayMaximum = $("input[name=Maximum]:checked").length == 1;
                if (displayMaximum && (datasetMaximumPerAccount[key] != null)) {
                    data.push(datasetMaximumPerAccount[key]);
                }
            }
        }
    });

    if (data.length > 0)

        $.plot($("#graphGeneral"), data,
        {
            series: {
                points: { show: showPoints },
                lines: { show: true }
            },
            xaxis: { mode: "time",
                min: minDisplayed,
                max : maxDisplayed
            },
            yaxis: { min: 0,
                transform: function (v) {
                    return Math.sqrt(v);
                },
                inverseTransform: function (v) {
                    return v * v;
                }
            },
            grid: { hoverable: true, clickable: true },
            legend: { show: true, container: $("#legend")},
            points: {radius: 2}
        });
}


function displayDateAccount(date) {
    if (date == null) {
        minDisplayed = maxDisplayed = null;
        showPoints = false;
    } else {
        minDisplayed = date;
        maxDisplayed = date + (24 * 60 * 60 * 1000);
        showPoints = true;
    }
    plotAccount();
}

function plotAccount() {
    $.plot($("#graphAccount"),
            [
                { label: "Délai (en secondes)", data: plotData , lines: { show: true }},
                { label: "Mails manquants", data: missData , lines: { show: false }}
            ],
    {
        series: {
            points: { show: showPoints }
        },
        xaxis: { mode: "time",
            min: minDisplayed,
            max : maxDisplayed
        },
        yaxis: { min: 0,
            transform: function (v) {
                return Math.sqrt(v);
            },
            inverseTransform: function (v) {
                return v * v;
            }
        },
        shadowSize: 0,
        points: {radius: 2},
        grid: { hoverable: true, clickable: true },
        legend: { show: true, container: $("#legend") }
    });
}

$(function () {
    $("#graphGeneral").bind("plothover", function (event, pos, item) {
        $("#x").text(pos.x.toFixed(2));
        $("#y").text(pos.y.toFixed(2));

        if (item) {
            if (previousPoint != item.datapoint) {
                previousPoint = item.datapoint;

                $("#tooltip").remove();
                var date = new Date(item.datapoint[0]);
                var toolTipString =
                        item.series.label + " "
                                + zeroPad(date.getUTCDate(), 2) + '/'
                                + zeroPad(date.getUTCMonth(), 2) + '/'
                                + zeroPad(date.getUTCFullYear(), 4) + ' '
                                + zeroPad(date.getUTCHours(), 2) + ':'
                                + zeroPad(date.getUTCMinutes(), 2) + ':'
                                + zeroPad(date.getUTCSeconds(), 2) + " &rarr; "
                                + item.datapoint[1] + "s";
                showTooltip(item.pageX, item.pageY,
                        toolTipString);
            }
        }
        else {
            $("#tooltip").remove();
            previousPoint = null;
        }
    });

    $("#graphGeneral").bind("plotclick", function (event, pos, item) {
        if (item) {
            var label = item.series.label;
            if ((label == 'Maximum') || (label == 'Moyenne')) {
                $(location).attr("href", "/message/" + (item.datapoint[0] / 1000));
            } else {
                $(location).attr("href", "/account/" + label + "/" + (item.datapoint[0] / 1000));
            }
        }
    });

    $(".plotCheck").click(plotGeneral);


    $("#graphAccount").bind("plothover", function (event, pos, item) {
        $("#x").text(pos.x.toFixed(2));
        $("#y").text(pos.y.toFixed(2));

        if (item) {
            if (previousPoint != item.datapoint) {
                previousPoint = item.datapoint;

                $("#tooltip").remove();
                var date = new Date(item.datapoint[0]);
                var toolTipString = zeroPad(date.getUTCDate(), 2) + '/'
                        + zeroPad(date.getUTCMonth(), 2) + '/'
                        + zeroPad(date.getUTCFullYear(), 4) + ' '
                        + zeroPad(date.getUTCHours(), 2) + ':'
                        + zeroPad(date.getUTCMinutes(), 2) + ':'
                        + zeroPad(date.getUTCSeconds(), 2) + " &rarr; "
                        + item.datapoint[1] + "s";
                showTooltip(item.pageX, item.pageY,
                        toolTipString);
            }
        }
        else {
            $("#tooltip").remove();
            previousPoint = null;
        }
    });

    $("#graphAccount").bind("plotclick", function (event, pos, item) {
        if (item) {
            if (item.series.seriesindex == 0) {
                $(location).attr("href", "/message/" + (item.datapoint[0] / 1000));
            } else {
                $(location).attr("href", "/account/" + accountName + "/" + (item.datapoint[0] / 1000));
            }
        }
    });

});