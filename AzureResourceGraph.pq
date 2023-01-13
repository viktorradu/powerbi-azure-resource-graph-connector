[Version = "1.0.0"]
section AzureResourceGraph;

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://login.windows.net/common/oauth2/token";
logout_uri = "https://login.microsoftonline.com/logout.srf";

[DataSource.Kind="AzureResourceGraph", Publish="AzureResourceGraph.Publish"]
shared AzureResourceGraph.Contents = Value.ReplaceType(AzureResourceGraph.Internal, AzureResourceGraphType);

AzureResourceGraphType = type function(
    subscriptionId as (type text meta [
        Documentation.FieldCaption = "Subscription Id",
        Documentation.FieldDescription = "Azure Subscription Id",
        Documentation.SampleValues = {"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}
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

AzureResourceGraph.Internal = (subscriptionId as text, optional query as text) =>
    let
        query = Text.ToBinary("{""subscriptions"":[""" & subscriptionId & """],""query"":""" & Text.Replace(query,"""", "'" ) & """}"),
        RawResponse = Web.Contents("https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01", [
            Headers = [#"Content-Type" = "application/json"],
            Content = query]),
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
