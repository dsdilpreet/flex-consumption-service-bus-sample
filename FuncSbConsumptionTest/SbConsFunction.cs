using System;
using System.Threading.Tasks;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FuncSbConsumptionTest
{
    public class SbConsFunction
    {
        private readonly ILogger<SbConsFunction> _logger;

        public SbConsFunction(ILogger<SbConsFunction> logger)
        {
            _logger = logger;
        }

        [Function(nameof(SbConsFunction))]
        public async Task Run(
            [ServiceBusTrigger("sbt-topic", "sbs-consumption", Connection = "ServiceBusConnectionString")]
            ServiceBusReceivedMessage message,
            ServiceBusMessageActions messageActions)
        {
            _logger.LogInformation("Message ID: {id}", message.MessageId);
            _logger.LogInformation("Message Body: {body}", message.Body);
            _logger.LogInformation("Message Content-Type: {contentType}", message.ContentType);

             // Complete the message
            await messageActions.CompleteMessageAsync(message);
        }
    }
}
