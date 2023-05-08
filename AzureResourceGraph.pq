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

AzureResourceGraph.Internal = (scope as text, subscriptionId as text, targetCloud as text, optional query as text) as table =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextToken = if (previous = null) then "" else Value.Metadata(previous)[NextToken]?,
            // if NextToken was set to null by the previous call, we know we have no more data
            page = if (nextToken <> null) then GetPage(scope, subscriptionId, nextToken, targetCloud, query) else null
        in
            page
    );

GetPage = (scope as text, subscriptionId as text, skipToken as text, targetCloud as text, optional query as text) as table =>
    let
        prefix = "{",
        scopeSegment = if scope = "Subscription" then """subscriptions"":[""" & subscriptionId & """]," else "",
        options = if skipToken = "" then "" else """options"": {""$skipToken"": """ & skipToken & """}, ",
        suffix = """query"":""" & Text.Replace(query,"""", "'" ) & """}",
        queryBytes = Text.ToBinary(prefix & scopeSegment & options & suffix),
        rootUrl = if targetCloud = "GCC High" then "https://management.usgovcloudapi.net" else "https://management.azure.com",
        RawResponse = Web.Contents(rootUrl & "/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01", [
             Headers = [#"Content-Type" = "application/json"],
             Content = queryBytes]),
        Response = Json.Document(RawResponse),
        nextToken = GetNextToken(Response),
        ResultTable = Table.FromList(Response[data], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        Result = try Table.ExpandRecordColumn(ResultTable, "Column1", Record.FieldNames(Table.Column(ResultTable, "Column1"){0})) otherwise #table({},{})
    in
        Result meta [NextToken = nextToken];

GetNextToken = (response) as nullable text => Record.FieldOrDefault(response, "$skipToken");

AzureResourceGraph = [
    TestConnection = (dataSourcePath) => 
        let
            params = Json.Document(dataSourcePath),
            scope = params[scope],
            subscriptionId = params[id],
            targetCloud = params[targetCloud]
        in
            {"AzureResourceGraph.Contents", scope, subscriptionId, targetCloud}
    ,
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

//
// Common functions from: https://learn.microsoft.com/en-us/power-query/helper-functions
//
// The getNextPage function takes a single argument and is expected to return a nullable table
Table.GenerateByPage = (getNextPage as function) as table =>
    let        
        listOfPages = List.Generate(
            () => getNextPage(null),            // get the first page of data
            (lastPage) => lastPage <> null,     // stop when the function returns null
            (lastPage) => getNextPage(lastPage) // pass the previous page to the next function call
        ),
        // concatenate the pages together
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else        
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );
