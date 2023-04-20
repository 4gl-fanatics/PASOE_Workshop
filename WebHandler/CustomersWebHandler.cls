
 /*------------------------------------------------------------------------
    File        : CustomersWebHandler
    Purpose     :
    Syntax      :
    Description :
    Author(s)   : mikef
    Created     : Thu Apr 20 13:43:42 CEST 2023
    Notes       :
  ----------------------------------------------------------------------*/

BLOCK-LEVEL ON ERROR UNDO, THROW.

USING OpenEdge.Core.Collections.* FROM PROPATH.
USING OpenEdge.Net.HTTP.*         FROM PROPATH.
USING OpenEdge.Web.*              FROM PROPATH.
USING Progress.Json.ObjectModel.* FROM PROPATH.
USING Progress.Lang.*             FROM PROPATH.

CLASS WebHandler.CustomersWebHandler INHERITS WebHandler:

    METHOD PRIVATE Progress.Json.ObjectModel.JsonObject GetCustomer (piCustNum AS INTEGER):

        DEFINE VARIABLE oCustomer AS Progress.Json.ObjectModel.JsonObject NO-UNDO.

        oCustomer = NEW JsonObject () .

        IF NOT CAN-FIND (Customer WHERE Customer.CustNum = piCustNum) THEN
            UNDO, THROW NEW Progress.Lang.AppError ("Kunde nicht gefunden - 404", 404) .

        FIND Customer WHERE Customer.CustNum = piCustNum NO-LOCK .

        oCustomer:Add ("CustNum", Customer.CustNum) .
        oCustomer:Add ("Name", Customer.Name) .
        oCustomer:Add ("City", Customer.City) .
        oCustomer:Add ("Country", Customer.Country) .

        RETURN oCustomer .

    END METHOD.


    METHOD PRIVATE Progress.Json.ObjectModel.JsonArray GetCustomerList (poRequest AS IWebRequest):

        DEFINE VARIABLE oCustomers AS Progress.Json.ObjectModel.JsonArray NO-UNDO.
        DEFINE VARIABLE oCustomer AS Progress.Json.ObjectModel.JsonObject NO-UNDO.

        DEFINE VARIABLE cNameFilter    AS CHARACTER NO-UNDO.
        DEFINE VARIABLE cCityFilter    AS CHARACTER NO-UNDO.
        DEFINE VARIABLE cCountryFilter AS CHARACTER NO-UNDO.
        DEFINE VARIABLE cQuickSearch   AS CHARACTER NO-UNDO.
        DEFINE VARIABLE cQueryString   AS CHARACTER NO-UNDO INITIAL "".

        DEFINE VARIABLE hQuery AS HANDLE NO-UNDO.
        DEFINE VARIABLE i AS INTEGER NO-UNDO.

        oCustomers = NEW JsonArray () .

        CREATE QUERY hQuery .
        hQuery:SET-BUFFERS (BUFFER Customer:HANDLE) .

        ASSIGN cNameFilter    = poRequest:URI:GetQueryValue("Name")
               cCityFilter    = poRequest:URI:GetQueryValue("City")
               cCountryFilter = poRequest:URI:GetQueryValue("Country")
               cQuickSearch   = poRequest:URI:GetQueryValue("q").

        IF cNAmeFilter > "" THEN
            ASSIGN cQueryString = cQueryString + (IF cQueryString > "" THEN " AND " ELSE " WHERE ") +
                                  SUBSTITUTE ("Name begins &1", QUOTER (cNameFilter)).

        IF cCityFilter > "" THEN
            ASSIGN cQueryString = cQueryString + (IF cQueryString > "" THEN " AND " ELSE " WHERE ") +
                                  SUBSTITUTE ("City begins &1", QUOTER (cCityFilter)).

        IF cCountryFilter > "" THEN
            ASSIGN cQueryString = cQueryString + (IF cQueryString > "" THEN " AND " ELSE " WHERE ") +
                                  SUBSTITUTE ("Country begins &1", QUOTER (cCountryFilter)).

        IF cQuickSearch > "" THEN
            ASSIGN cQueryString = cQueryString + (IF cQueryString > "" THEN " AND " ELSE " WHERE ") +
                             SUBSTITUTE ("(Name begins &1 or City begins &1 or Country begins &1)",
                                         QUOTER (cQuickSearch)).

        ASSIGN cQueryString = SUBSTITUTE ("for each Customer &1 no-lock", cQueryString) .

MESSAGE
"cNameFilter    " cNameFilter    SKIP
"cCityFilter    " cCityFilter    SKIP
"cCountryFilter " cCountryFilter SKIP
"cQuickSearch   " cQuickSearch   SKIP
"Query" cQueryString

    VIEW-AS ALERT-BOX.

        hQuery:QUERY-PREPARE (cQueryString) .
        hQuery:QUERY-OPEN () .
        hQuery:GET-FIRST (NO-LOCK) .

        customerLoop:
        DO WHILE NOT hQuery:QUERY-OFF-END:
            i = i + 1 .

            IF i > 20 THEN
                LEAVE customerLoop.

            oCustomer = NEW JsonObject () .

            oCustomer:Add ("url",
                           SUBSTITUTE ("&1&2/&3",
                                       poRequest:URI:BaseURI,
                                       poRequest:URI:Path,
                                       Customer.CustNum)) .

            oCustomer:Add ("CustNum", Customer.CustNum) .
            oCustomer:Add ("Name", Customer.Name) .
            oCustomer:Add ("City", Customer.City) .
            oCustomer:Add ("Country", Customer.Country) .

            oCustomers:Add (oCustomer) .

            hQuery:GET-NEXT (NO-LOCK).
        END.

        RETURN oCustomers.

        FINALLY:
            IF VALID-HANDLE (hQuery) THEN
                DELETE OBJECT hQuery .
        END FINALLY.

    END METHOD.

    METHOD OVERRIDE PROTECTED INTEGER HandleNotAllowedMethod( INPUT poRequest AS OpenEdge.Web.IWebRequest ):

        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").

    END METHOD.

    METHOD OVERRIDE PROTECTED INTEGER HandleNotImplemented( INPUT poRequest AS OpenEdge.Web.IWebRequest ):

        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").

    END METHOD.



    /*------------------------------------------------------------------------------
            Purpose: Default handler for the HTTP GET method. The request being
                     serviced and an optional status code is returned. A zero or
                     null value means this method will deal with all errors.
            Notes:
    ------------------------------------------------------------------------------*/
     METHOD OVERRIDE PROTECTED INTEGER HandleGet( INPUT poRequest AS OpenEdge.Web.IWebRequest ):


        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse         NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter          NO-UNDO.
        DEFINE VARIABLE oBody     AS Progress.Json.ObjectModel.JsonConstruct NO-UNDO.

        DEFINE VARIABLE cCustNum AS CHARACTER NO-UNDO.
        DEFINE VARIABLE iCustNum AS INTEGER NO-UNDO.

        ASSIGN cCustNum = poRequest:GetPathParameter("CustNum") .

        IF cCustNum > "" THEN DO:
            ASSIGN iCustNum = INTEGER (cCustNum) NO-ERROR .

            ERROR-STATUS:ERROR = FALSE NO-ERROR .

            IF iCustNum > 0 THEN
                oBody = GetCustomer (iCustNum) .
            ELSE
                UNDO, THROW NEW AppError ("Ungültige Kundennummer", 0) .
        END.
        ELSE
            oBody = GetCustomerList (poRequest) .

        /* The WebResponse body is a wrapper around an entire HTTP response message.
           It contains a status code and reason; headers; cookies and a message body.

           API-level doc for this and related classes can be found at
           https://documentation.progress.com/output/oehttpclient/      */
        ASSIGN
            oResponse            = NEW OpenEdge.Web.WebResponse()
            oResponse:StatusCode = INTEGER(StatusCodeEnum:OK)
            .

        ASSIGN
            oResponse:Entity        = oBody
            /* HTTP messages require a content type */
            oResponse:ContentType   = 'application/json':u
            /* ContentLength is good too */
            //oResponse:ContentLength = oBody:Size
            .

        /* The WebResponseWriter ensures that the status line and
           all headers are writted out before the message body/entity. */
        ASSIGN
            oWriter = NEW WebResponseWriter(oResponse).
        oWriter:Open().

        /* Finish writing the response message */
        oWriter:Close().

        /* A response of 0 means that this handler will build the entire response;
           a non-zero value is mapped to a static handler in the webapp's /static/error folder.
           The mappings are maintained in the webapps's WEB-INF/web.xml
           A predefined set of HTTP status codes is provided in the OpenEdge.Net.HTTP.StatusCodeEnum
           enumeration */
        RETURN 0.

     END METHOD.


      /*------------------------------------------------------------------------------
            Purpose:
            Notes:
    ------------------------------------------------------------------------------*/
      METHOD OVERRIDE PROTECTED INTEGER HandlePut( INPUT poRequest AS OpenEdge.Web.IWebRequest ):

        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse         NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter          NO-UNDO.
        DEFINE VARIABLE oBody     AS Progress.Json.ObjectModel.JsonConstruct NO-UNDO.

        DEFINE VARIABLE cCustNum AS CHARACTER NO-UNDO.
        DEFINE VARIABLE iCustNum AS INTEGER NO-UNDO.

        ASSIGN cCustNum = poRequest:GetPathParameter("CustNum") .

        IF cCustNum > "" THEN DO:
            ASSIGN iCustNum = INTEGER (cCustNum) NO-ERROR .

            ERROR-STATUS:ERROR = FALSE NO-ERROR .

            IF iCustNum > 0 THEN
                UpdateCustomer (iCustNum, poRequest).
            ELSE
                UNDO, THROW NEW AppError ("Ungültige Kundennummer", 404) .
        END.
        ELSE
            UNDO, THROW NEW AppError ("Ungültige Kundennummer", 404) .

        /* The WebResponse body is a wrapper around an entire HTTP response message.
           It contains a status code and reason; headers; cookies and a message body.

           API-level doc for this and related classes can be found at
           https://documentation.progress.com/output/oehttpclient/      */
        ASSIGN
            oResponse            = NEW OpenEdge.Web.WebResponse()
            oResponse:StatusCode = INTEGER(StatusCodeEnum:OK)
            .

oBody = GetCustomer (iCustNum).

        ASSIGN
            oResponse:Entity        = oBody
            /* HTTP messages require a content type */
            oResponse:ContentType   = 'application/json':u
            /* ContentLength is good too */
            //oResponse:ContentLength = oBody:Size
            .

        /* The WebResponseWriter ensures that the status line and
           all headers are writted out before the message body/entity. */
        ASSIGN
            oWriter = NEW WebResponseWriter(oResponse).
        oWriter:Open().

        /* Finish writing the response message */
        oWriter:Close().

        /* A response of 0 means that this handler will build the entire response;
           a non-zero value is mapped to a static handler in the webapp's /static/error folder.
           The mappings are maintained in the webapps's WEB-INF/web.xml
           A predefined set of HTTP status codes is provided in the OpenEdge.Net.HTTP.StatusCodeEnum
           enumeration */
        RETURN 0.

      END METHOD.



      /*------------------------------------------------------------------------------
            Purpose:
            Notes:
    ------------------------------------------------------------------------------*/
      METHOD OVERRIDE PROTECTED INTEGER HandlePatch( INPUT poRequest AS OpenEdge.Web.IWebRequest ):

        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse         NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter          NO-UNDO.
        DEFINE VARIABLE oBody     AS Progress.Json.ObjectModel.JsonConstruct NO-UNDO.

        DEFINE VARIABLE cCustNum AS CHARACTER NO-UNDO.
        DEFINE VARIABLE iCustNum AS INTEGER NO-UNDO.

        ASSIGN cCustNum = poRequest:GetPathParameter("CustNum") .

        IF cCustNum > "" THEN DO:
            ASSIGN iCustNum = INTEGER (cCustNum) NO-ERROR .

            ERROR-STATUS:ERROR = FALSE NO-ERROR .

            IF iCustNum > 0 THEN
                PatchCustomer (iCustNum, poRequest).
            ELSE
                UNDO, THROW NEW AppError ("Ungültige Kundennummer", 404) .
        END.
        ELSE
            UNDO, THROW NEW AppError ("Ungültige Kundennummer", 404) .

        /* The WebResponse body is a wrapper around an entire HTTP response message.
           It contains a status code and reason; headers; cookies and a message body.

           API-level doc for this and related classes can be found at
           https://documentation.progress.com/output/oehttpclient/      */
        ASSIGN
            oResponse            = NEW OpenEdge.Web.WebResponse()
            oResponse:StatusCode = INTEGER(StatusCodeEnum:OK)
            .

oBody = GetCustomer (iCustNum).

        ASSIGN
            oResponse:Entity        = oBody
            /* HTTP messages require a content type */
            oResponse:ContentType   = 'application/json':u
            /* ContentLength is good too */
            //oResponse:ContentLength = oBody:Size
            .

        /* The WebResponseWriter ensures that the status line and
           all headers are writted out before the message body/entity. */
        ASSIGN
            oWriter = NEW WebResponseWriter(oResponse).
        oWriter:Open().

        /* Finish writing the response message */
        oWriter:Close().

        /* A response of 0 means that this handler will build the entire response;
           a non-zero value is mapped to a static handler in the webapp's /static/error folder.
           The mappings are maintained in the webapps's WEB-INF/web.xml
           A predefined set of HTTP status codes is provided in the OpenEdge.Net.HTTP.StatusCodeEnum
           enumeration */
        RETURN 0.

      END METHOD.

    METHOD PRIVATE VOID UpdateCustomer (piCustNum AS INTEGER,
                                        poRequest AS IWebRequest):

        DEFINE VARIABLE oCustomer AS JsonObject NO-UNDO.
        DEFINE BUFFER Customer FOR Customer .

        IF    NOT poRequest:GetHeader("Content-Type"):Value = "application/json"
           OR NOT TYPE-OF (poRequest:Entity, JsonObject) THEN
            UNDO, THROW NEW Progress.Lang.AppError ("Bad request", 400) .

        oCustomer = CAST (poRequest:Entity, JsonObject).

        FIND Customer WHERE Customer.CustNum = piCustNum EXCLUSIVE-LOCK .

        ASSIGN Customer.Name = oCustomer:GetCharacter("Name")
               Customer.City = oCustomer:GetCharacter("City")
               Customer.Country = oCustomer:GetCharacter("Country") .

    END METHOD.

    METHOD PRIVATE VOID PatchCustomer (piCustNum AS INTEGER,
                                        poRequest AS IWebRequest):

        DEFINE VARIABLE oCustomer AS JsonObject NO-UNDO.
        DEFINE BUFFER Customer FOR Customer .

        IF    NOT poRequest:GetHeader("Content-Type"):Value = "application/json"
           OR NOT TYPE-OF (poRequest:Entity, JsonObject) THEN
            UNDO, THROW NEW Progress.Lang.AppError ("Bad request", 400) .

        oCustomer = CAST (poRequest:Entity, JsonObject).

        FIND Customer WHERE Customer.CustNum = piCustNum EXCLUSIVE-LOCK .

        IF oCustomer:Has ("Name") THEN
            ASSIGN Customer.Name = oCustomer:GetCharacter("Name") .

        IF oCustomer:Has ("City") THEN
               Customer.City = oCustomer:GetCharacter("City") .

        IF oCustomer:Has ("Country") THEN
               Customer.Country = oCustomer:GetCharacter("Country") .

    END METHOD.

     /*------------------------------------------------------------------------------
            Purpose:
            Notes:
    ------------------------------------------------------------------------------*/
     METHOD OVERRIDE PROTECTED INTEGER HandlePost( INPUT poRequest AS OpenEdge.Web.IWebRequest ):

        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").
      END METHOD.

      /*------------------------------------------------------------------------------
            Purpose:
            Notes:
    ------------------------------------------------------------------------------*/
       METHOD OVERRIDE PROTECTED INTEGER HandleDelete( INPUT poRequest AS OpenEdge.Web.IWebRequest ):

        UNDO, THROW NEW Progress.Lang.AppError("METHOD NOT IMPLEMENTED").
      END METHOD.


END CLASS.