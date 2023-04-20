 
 /*------------------------------------------------------------------------
    File        : HelloWorldWebHandler
    Purpose     : 
    Syntax      : 
    Description : 
    Author(s)   : mikef
    Created     : Thu Apr 20 05:35:26 CEST 2023
    Notes       : 
  ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING OpenEdge.Web.WebResponseWriter.
USING OpenEdge.Net.HTTP.StatusCodeEnum.
USING OpenEdge.Web.WebHandler.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS WebHandler.HelloWorldHtmlWebHandler INHERITS WebHandler: 

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
     
    
        DEFINE VARIABLE oResponse AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.
        DEFINE VARIABLE oWriter   AS OpenEdge.Web.WebResponseWriter  NO-UNDO.
        DEFINE VARIABLE oBody     AS OpenEdge.Core.String            NO-UNDO.
            
        /* The WebResponse body is a wrapper around an entire HTTP response message.
           It contains a status code and reason; headers; cookies and a message body.
           
           API-level doc for this and related classes can be found at
           https://documentation.progress.com/output/oehttpclient/      */
        ASSIGN 
            oResponse            = NEW OpenEdge.Web.WebResponse()
            oResponse:StatusCode = INTEGER(StatusCodeEnum:OK)
            .
            
        IF poRequest:HasHeader("Accept":U) AND 
            LOOKUP ("text/html", poRequest:GetHeader("Accept":U):Value) > 0 THEN 

            ASSIGN 
                oBody = NEW OpenEdge.Core.String(
                    "<html><head><title>Hello World</title></head><body>" +
                
                                 'Hello mikef'
                               + '~r~n':u   /*CRLF */
                               + 'This message was returned by <font color=red>HandleGet</font> in HelloWorldWebHandler.'
                    + "</body></html>"                                
                               )
               oResponse:ContentType   = 'text/html':u .

                
        ELSE  
            /* This body object can be a string or something else (JsonObject for instance) */               
            ASSIGN 
                oBody = NEW OpenEdge.Core.String(
                                 'Hello mikef'
                               + '~r~n':u   /*CRLF */
                               + 'This message was returned by HandleGet in HelloWorldWebHandler.'
                               )
                oResponse:ContentType   = 'text/plain':u .
        
        ASSIGN 
            oResponse:Entity        = oBody
            /* HTTP messages require a content type */
            /* ContentLength is good too */
            oResponse:ContentLength = oBody:Size
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
     
END CLASS.