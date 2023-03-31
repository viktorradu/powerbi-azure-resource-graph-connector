# Azure Resource Graph Connector for Power BI

Build any query in Azure Resource Graph Explorer and use it in Power BI reports

Example usage in Power Query:


```javascript
let
    Source = AzureResourceGraph.Contents("Subscription", "972bf231-2ce4-...", "Commercial", "Resources | limit 5")
in 
    Source
```
# Scope selection:
- Subscription scope will filter all query results by subscription
- Directory scope will run the query as-is, the resource list is still restricted by the user permissions