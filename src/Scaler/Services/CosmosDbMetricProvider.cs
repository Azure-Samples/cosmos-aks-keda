using System;
using System.ComponentModel;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using Azure.Identity;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Client.Platforms.Features.DesktopOs.Kerberos;
using Container = Microsoft.Azure.Cosmos.Container;

namespace Keda.CosmosDb.Scaler
{
    internal sealed class CosmosDbMetricProvider : ICosmosDbMetricProvider
    {
        private readonly CosmosDbFactory _factory;
        private readonly ILogger<CosmosDbMetricProvider> _logger;

        public CosmosDbMetricProvider(CosmosDbFactory factory, ILogger<CosmosDbMetricProvider> logger)
        {
            _factory = factory ?? throw new ArgumentNullException(nameof(factory));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<long> GetPartitionCountAsync(ScalerMetadata scalerMetadata)
        {
            try
            {
                _logger.LogInformation("Before cosmosClient");

                var credential = new DefaultAzureCredential();
                var cosmosClient = new CosmosClient(scalerMetadata.Endpoint, credential);

                _logger.LogInformation("After cosmosClient");

                Container leaseContainer = cosmosClient.GetContainer(scalerMetadata.LeaseDatabaseId, scalerMetadata.LeaseContainerId);
                Container monitoredContainer = cosmosClient.GetContainer(scalerMetadata.DatabaseId, scalerMetadata.ContainerId);

                _logger.LogInformation("after containers");

                ChangeFeedEstimator changeFeedEstimator = monitoredContainer.GetChangeFeedEstimator("SalesOrderChangeFeed", leaseContainer);

                _logger.LogInformation("Before estimatorIterator");

                using FeedIterator<ChangeFeedProcessorState> estimatorIterator = changeFeedEstimator.GetCurrentStateIterator();
                int partitionCount = 0;

                _logger.LogInformation("Before Iterator");

                while (estimatorIterator.HasMoreResults)
                {
                    FeedResponse<ChangeFeedProcessorState> states = await estimatorIterator.ReadNextAsync();
                    foreach (ChangeFeedProcessorState leaseState in states)
                    {
                        string host = leaseState.InstanceName == null ? $"not owned by any host currently" : $"owned by host {leaseState.InstanceName}";
                        _logger.LogInformation($"Lease [{leaseState.LeaseToken}] {host} reports {leaseState.EstimatedLag} as estimated lag.");               
                       
                    }
                    partitionCount += states.Where(state => state.EstimatedLag > 0).Count();
                }
                _logger.LogInformation($"After Iterator, Partition Count:{partitionCount}");

                return partitionCount;

            }
            catch (CosmosException exception)
            {
                _logger.LogWarning($"Encountered exception {exception.GetType()}: {exception.Message}");
            }
            catch (InvalidOperationException exception)
            {
                _logger.LogWarning($"Encountered exception {exception.GetType()}: {exception.Message}");
                throw;
            }
            catch (HttpRequestException exception)
            {
                var webException = exception.InnerException as WebException;
                if (webException?.Status == WebExceptionStatus.ProtocolError)
                {
                    var response = (HttpWebResponse)webException.Response;
                    _logger.LogWarning($"Encountered error response {response.StatusCode}: {response.StatusDescription}");
                }
                else
                {
                    _logger.LogWarning($"Encountered exception {exception.GetType()}: {exception.Message}");
                }
            }

            return 0L;
        }
    }
}
