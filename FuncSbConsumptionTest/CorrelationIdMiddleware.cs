using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Azure.Functions.Worker.Middleware;
using Microsoft.Extensions.Logging;

namespace FuncSbConsumptionTest
{
    /// <summary>
    /// Pulls the correlation ID from http request headers,
    /// saves into context and log scope,
    /// and adds it into any response.
    /// </summary>
    public class CorrelationIdMiddleware : IFunctionsWorkerMiddleware
    {
        private readonly ILogger _logger;
        private const string CorrelationIdKey = "CorrelationId";

        public CorrelationIdMiddleware(ILogger<CorrelationIdMiddleware> logger)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task Invoke(FunctionContext context, FunctionExecutionDelegate next)
        {
            var correlationId = await GetCorrelationId(context);

            var logScope = new Dictionary<string, object> { { CorrelationIdKey, correlationId } };
            using (_logger.BeginScope(logScope))
            {
                // Add correlation id to context so we have access to it elsewhere.
                context.Items.Add(CorrelationIdKey, correlationId);

                await next(context);
                try
                {
                    InsertCorrelationIdIntoResponse(context, correlationId);
                }
#pragma warning disable CA1031 // ignore error if we couldnt inject correlation id in response but application should continue executing
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Unexpected error while setting correlation id. Exception: {ExceptionMessage}.", ex.Message);
                }
#pragma warning restore CA1031
            }
        }

        private async Task<Guid?> GetCorrelationId(FunctionContext context)
        {
            Guid? result = null;

            var httpRequestData = await context.GetHttpRequestDataAsync();

            if (httpRequestData != null)
                return HandleHttpRequest(httpRequestData) ?? result;

            // service bus
            return HandleNonHttpRequest(context) ?? result;
        }

        private Guid? HandleNonHttpRequest(FunctionContext context)
        {
            if (context.BindingContext.BindingData.TryGetValue(CorrelationIdKey, out var rawCorrelationIdStr))
                if (rawCorrelationIdStr is string correlationIdStr && Guid.TryParse(correlationIdStr, out var correlationId))
                    return correlationId;

            _logger.LogWarning("Invalid CorrelationId. Cannot find matching correlation id key in event. Expected key is: {CorrelationIdKey}.", CorrelationIdKey);
            return null;
        }

        private Guid? HandleHttpRequest(HttpRequestData httpRequestData)
        {
            if (!httpRequestData.Headers.TryGetValues(CorrelationIdKey, out var correlationIdValues))
            {
                _logger.LogWarning("Invalid CorrelationId. Cannot find matching correlation id key in request. Expected key is: {CorrelationIdKey}.", CorrelationIdKey);
                return null;
            }

            if (!correlationIdValues.Any())
            {
                _logger.LogWarning("Invalid CorrelationId. Headers contain no correlation id.");
                return null;
            }

            if (correlationIdValues.Count() > 1)
                _logger.LogWarning("Invalid CorrelationId. Headers contain more than 1 correlation id as a list. Value is: {CorrelationIdValues}.", string.Join(",", correlationIdValues));

            var ids = correlationIdValues.First().Split(",");
            if (ids.Length > 1)
                _logger.LogWarning("Invalid CorrelationId. Headers contain more than 1 correlation id. Value is: {CorrelationIdValues}.", string.Join(",", correlationIdValues));

            if (!Guid.TryParse(ids.First(), out var correlationId))
            {
                _logger.LogWarning("Invalid CorrelationId. Unable to parse correlation id to GUID from value: {CorrelationIdValue}.", ids.First());
                return null;
            }

            return correlationId;
        }



        /// <summary>
        /// Insert a correlation ID into the function response headers.
        /// </summary>
        /// <param name="context"></param>
        /// <param name="correlationId"></param>
        /// <returns></returns>
        private HttpResponseData InsertCorrelationIdIntoResponse(FunctionContext context, Guid? correlationId)
        {
            var response = context.GetHttpResponseData();
            if (correlationId != null)
                response?.Headers.Add(CorrelationIdKey, correlationId.ToString());
            return response;
        }
    }
}
