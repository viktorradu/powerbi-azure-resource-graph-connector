[Version = "1.0.0"]
section AzureResourceGraph;

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://login.windows.net/common/oauth2/token";
logout_uri = "https://login.microsoftonline.com/logout.srf";

[DataSource.Kind="AzureResourceGraph", Publish="AzureResourceGraph.Publish"]
shared AzureResourceGraph.Contents = Value.ReplaceType(AzureResourceGraph.Internal, AzureResourceGraphType);

AzureResourceGraphType = type function(
    scope as (type text meta [
        Documentation.FieldCaption = "Scope",
        Documentation.FieldDescription = "Query scope",
        Documentation.AllowedValues = {"Directory", "Subscription"}
    ]),
    id as (type text meta [
        Documentation.FieldCaption = "Id",
        Documentation.FieldDescription = "Azure Directory or Subscription Id",
        Documentation.SampleValues = {"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}
    ]),
    targetCloud as (type text meta [
        Documentation.FieldCaption = "Environment",
        Documentation.FieldDescription = "Target cloud environment",
        Documentation.AllowedValues = {"Commercial", "GCC High"}
    ]),
    optional query as (type text meta [
        Documentation.FieldCaption = "Query",
        Documentation.FieldDescription = "Azure Resource Graph Explorer query",
        Formatting.IsMultiLine = true,
        Documentation.SampleValues = {"Resources
        | project name, type
        | top 100"}
    ])
) as table meta [
        Documentation.Name = Extension.LoadString("ConnectorName"),
        Documentation.LongDescription = Extension.LoadString("ConnectorDescription")
    ];

AzureResourceGraph.Internal = (scope as text, subscriptionId as text, targetCloud as text, optional query as text) =>
    let
        prefix = "{",
        scopeSegment = if scope = "Subscription" then """subscriptions"":[""" & subscriptionId & """]," else "",
        suffix = """query"":""" & Text.Replace(query,"""", "'" ) & """}",
        queryBytes = Text.ToBinary(prefix & scopeSegment & suffix),
        rootUrl = if targetCloud = "GCC High" then "https://management.usgovcloudapi.net" else "https://management.azure.com",
        RawResponse = Web.Contents(rootUrl & "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01", [
             Headers = [#"Content-Type" = "application/json"],
             Content = queryBytes]),
        Response = Json.Document(RawResponse),
        ResultTable = Table.FromList(Response[data], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        Result = try Table.ExpandRecordColumn(ResultTable, "Column1", Record.FieldNames(Table.Column(ResultTable, "Column1"){0})) otherwise #table({},{})
    in
        Result;

AzureResourceGraph = [
    Authentication = [
        Aad = [
            AuthorizationUri = "https://login.microsoftonline.com/common/oauth2/authorize",
            Resource = "https://management.azure.com/"
        ]
    ]
];

// Data Source UI publishing description
AzureResourceGraph.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = AzureResourceGraph.Icons,
    SourceTypeImage = AzureResourceGraph.Icons
];

AzureResourceGraph.Icons = [
    Icon16 = { Extension.Contents("AzureResourceGraph16.png"), Extension.Contents("AzureResourceGraph20.png"), Extension.Contents("AzureResourceGraph24.png"), Extension.Contents("AzureResourceGraph32.png") },
    Icon32 = { Extension.Contents("AzureResourceGraph32.png"), Extension.Contents("AzureResourceGraph40.png"), Extension.Contents("AzureResourceGraph48.png"), Extension.Contents("AzureResourceGraph64.png") }
];
