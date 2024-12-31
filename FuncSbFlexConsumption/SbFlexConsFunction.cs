using System;
using System.Threading.Tasks;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FuncSbFlexConsumption
{
    public class SbFlexConsFunction
    {
        private readonly ILogger<SbFlexConsFunction> _logger;

        public SbFlexConsFunction(ILogger<SbFlexConsFunction> logger)
        {
            _logger = logger;
        }

        [Function(nameof(SbFlexConsFunction))]
        public async Task Run(
            [ServiceBusTrigger("sbt-topic", "sbs-flexconsumption", Connection = "ServiceBusConnectionString")]
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
