﻿// WooCommerce Copyright information https://woocommerce.com/style-guide/ - This Custom Connector is in no way affiliated with WooCommerce and is completely free of charge.
section WooCommerce;

Orders_Per_Page = "50"; // Changing this value would affect the amount of calls that you make. Lower value = More Calls, Higher Value = Less Calls

// WooCommerce REST API Documentation--> http://woocommerce.github.io/woocommerce-rest-api-docs/



 WooCommerce.Orders = (url as text) =>
    let
        Orders =  Web.Contents(url),
        Data = Json.Document( Orders),
    Metadata = Value.Metadata( Orders) [Headers] [Link],
    SplitToRows =  Text.Split(Metadata, ","),
    ToTable = Table.FromList(SplitToRows, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    SplitToColumns = Table.SplitColumn(ToTable, "Column1", Splitter.SplitTextByDelimiter(";", QuoteStyle.Csv), {"url", "type"}),
    TrimValues= Table.TransformColumns(SplitToColumns,{{"url", Text.Trim, type text}, {"type", Text.Trim, type text}}),
    NextLink=   Text.Remove(TrimValues{[type="rel=next"]}[url]?,{"<",">"})

    in
    Data meta [NextLink= try NextLink otherwise null];

[DataSource.Kind="WooCommerce", Publish="WooCommerce.Publish"]  
shared WooCommerce.Contents = Value.ReplaceType(WooCommerce.Navigation, ConnectorParams);

ConnectorParams = type function (
   siteurl as (type text meta [
   Documentation.FieldCaption = "The https url of your WooCommerce site",
   Documentation.SampleValues = {"https://www.poweredsolutions.co"}
   ]),
   api_version as  (type text meta[
    Documentation.FieldCaption = "Choose your API version",
    Documentation.FieldDescription = "For WooCommerce 2.6.x choose v1, for WooCommerce 3.0.x or later choose v2",
    Documentation.AllowedValues = { "v1", "v2" }]
    )) as table ;

 WooCommerce.Navigation = ( siteurl as text, api_version as text) =>
       let
        objects = #table(
            {"Name",       "Key",  "Data",                "ItemKind", "ItemName", "IsLeaf"},{
            {"Orders",   "Orders",  WooCommerce.Sales(siteurl, api_version) , "Table",    "Table",    true},
            {"OrdersByDate",   "OrdersByDate",  WooCommerce.OrdersByDate , "Function",    "Function",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

WooCommerce.OrdersByDate = (siteurl as text, api_version as text, StartDate as datetime, EndDate as datetime) =>
    let
       FirstDate = DateTime.ToText( StartDate, "yyyy-MM-ddThh:mm:ss"),
       LastDate = DateTime.ToText( EndDate, "yyyy-MM-ddThh:mm:ss"),
       InitialURL = Uri.Combine( siteurl, "/wp-json/wc/" & api_version & "/orders?after="&FirstDate&"&before="&LastDate),
       Pagination = List.Generate( ()=>
           [Result = try WooCommerce.Orders(InitialURL) otherwise null, NextLink = Value.Metadata(Result)[NextLink]],
           each [Result] <> null ,
            each    [Result=  try WooCommerce.Orders( [NextLink]) otherwise null, 
                    NextLink=Value.Metadata(Result)[NextLink]], 
               each [Result]),
    ListsInTable = Table.FromList( Pagination, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandListColumn = Table.ExpandListColumn( ListsInTable, "Column1"),
    ExpandRecords = Table.ExpandRecordColumn(ExpandListColumn, "Column1", 
    {"id", "parent_id", "number", "order_key", "created_via", "version", "status", "currency", "date_created", "date_created_gmt", "date_modified", "date_modified_gmt", "discount_total", "discount_tax", "shipping_total", "shipping_tax", "cart_tax", "total", "total_tax", "prices_include_tax", "customer_id", "customer_ip_address", "customer_user_agent", "customer_note", "billing", "shipping", "payment_method", "payment_method_title", "transaction_id", "date_paid", "date_paid_gmt", "date_completed", "date_completed_gmt", "cart_hash", "meta_data", "line_items", "tax_lines", "shipping_lines", "fee_lines", "coupon_lines", "refunds", "_links"}, 
    {"id", "parent_id", "number", "order_key", "created_via", "version", "status", "currency", "date_created", "date_created_gmt", "date_modified", "date_modified_gmt", "discount_total", "discount_tax", "shipping_total", "shipping_tax", "cart_tax", "total", "total_tax", "prices_include_tax", "customer_id", "customer_ip_address", "customer_user_agent", "customer_note", "billing", "shipping", "payment_method", "payment_method_title", "transaction_id", "date_paid", "date_paid_gmt", "date_completed", "date_completed_gmt", "cart_hash", "meta_data", "line_items", "tax_lines", "shipping_lines", "fee_lines", "coupon_lines", "refunds", "_links"}),
    DataTypes = Table.TransformColumnTypes(ExpandRecords,{{"id", Int64.Type}, {"number", type text}, {"parent_id", Int64.Type}, {"order_key", type text}, {"created_via", type text}, {"version", type text}, {"status", type text}, {"currency", type text}, {"date_created", type datetime}, {"date_created_gmt", type datetime}, {"date_modified", type datetime}, {"date_modified_gmt", type datetime}, {"discount_total", type number}, {"discount_tax", type number}, {"shipping_total", type number}, {"shipping_tax", type number}, {"cart_tax", type number}, {"total", type number}, {"total_tax", type number}, {"prices_include_tax", type logical}, {"customer_id", Int64.Type}, {"customer_ip_address", type text}, {"customer_user_agent", type text}, {"customer_note", type text}, {"payment_method", type text}, {"payment_method_title", type text}, {"transaction_id", type text}, {"date_paid", type datetime}, {"date_paid_gmt", type datetime}, {"date_completed", type datetime}, {"date_completed_gmt", type datetime}, {"cart_hash", type text}})
in
        DataTypes;

WooCommerce.Sales = (siteurl as text, api_version as text) =>
    let
            InitialURL = Uri.Combine( siteurl, "/wp-json/wc/" & api_version & "/orders"),
            Pagination = List.Generate( ()=>
           [Result = try WooCommerce.Orders(InitialURL) otherwise null, NextLink = Value.Metadata(Result)[NextLink]],
           each [Result] <> null ,
            each    [Result=  try WooCommerce.Orders( [NextLink]) otherwise null, 
                    NextLink=Value.Metadata(Result)[NextLink]], 
               each [Result]),
    ListsInTable = Table.FromList( Pagination, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandListColumn = Table.ExpandListColumn( ListsInTable, "Column1"),
    ExpandRecords = Table.ExpandRecordColumn(ExpandListColumn, "Column1", 
    {"id", "parent_id", "number", "order_key", "created_via", "version", "status", "currency", "date_created", "date_created_gmt", "date_modified", "date_modified_gmt", "discount_total", "discount_tax", "shipping_total", "shipping_tax", "cart_tax", "total", "total_tax", "prices_include_tax", "customer_id", "customer_ip_address", "customer_user_agent", "customer_note", "billing", "shipping", "payment_method", "payment_method_title", "transaction_id", "date_paid", "date_paid_gmt", "date_completed", "date_completed_gmt", "cart_hash", "meta_data", "line_items", "tax_lines", "shipping_lines", "fee_lines", "coupon_lines", "refunds", "_links"}, 
    {"id", "parent_id", "number", "order_key", "created_via", "version", "status", "currency", "date_created", "date_created_gmt", "date_modified", "date_modified_gmt", "discount_total", "discount_tax", "shipping_total", "shipping_tax", "cart_tax", "total", "total_tax", "prices_include_tax", "customer_id", "customer_ip_address", "customer_user_agent", "customer_note", "billing", "shipping", "payment_method", "payment_method_title", "transaction_id", "date_paid", "date_paid_gmt", "date_completed", "date_completed_gmt", "cart_hash", "meta_data", "line_items", "tax_lines", "shipping_lines", "fee_lines", "coupon_lines", "refunds", "_links"}),
    DataTypes = Table.TransformColumnTypes(ExpandRecords,{{"id", Int64.Type}, {"number", type text}, {"parent_id", Int64.Type}, {"order_key", type text}, {"created_via", type text}, {"version", type text}, {"status", type text}, {"currency", type text}, {"date_created", type datetime}, {"date_created_gmt", type datetime}, {"date_modified", type datetime}, {"date_modified_gmt", type datetime}, {"discount_total", type number}, {"discount_tax", type number}, {"shipping_total", type number}, {"shipping_tax", type number}, {"cart_tax", type number}, {"total", type number}, {"total_tax", type number}, {"prices_include_tax", type logical}, {"customer_id", Int64.Type}, {"customer_ip_address", type text}, {"customer_user_agent", type text}, {"customer_note", type text}, {"payment_method", type text}, {"payment_method_title", type text}, {"transaction_id", type text}, {"date_paid", type datetime}, {"date_paid_gmt", type datetime}, {"date_completed", type datetime}, {"date_completed_gmt", type datetime}, {"cart_hash", type text}})
in
        DataTypes;



// Data Source Kind description
WooCommerce = [
TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            siteurl = Text.Replace (json[siteurl], "\", "") ,
            api_version = json[api_version]
        in
            { "WooCommerce.Contents", siteurl, api_version },
    Authentication = [
                UsernamePassword = [UsernameLabel= "Consumer Key",
                                    PasswordLabel= "Consumer Secret",
                                    Label= "API Credentials"]
                    // Information on how to create the username and password for the REST API 
                    // http://woocommerce.github.io/woocommerce-rest-api-docs/#authentication 
    ]];


// Data Source UI publishing description
WooCommerce.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = WooCommerce.Icons,
    SourceTypeImage = WooCommerce.Icons
];

WooCommerce.Icons = [
    Icon16 = { Extension.Contents("WooCommerce16.png"), Extension.Contents("WooCommerce20.png"), Extension.Contents("WooCommerce24.png"), Extension.Contents("WooCommerce32.png") },
    Icon32 = { Extension.Contents("WooCommerce32.png"), Extension.Contents("WooCommerce40.png"), Extension.Contents("WooCommerce48.png"), Extension.Contents("WooCommerce64.png") }
];



Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = dataColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;