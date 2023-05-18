using System;
using System.Linq;
using System.Threading.Tasks;
using Bogus;
using Bogus.DataSets;
using Keda.CosmosDb.Scaler.Demo.Shared;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Hosting;
using Database = Microsoft.Azure.Cosmos.Database;
using Azure.Identity;
using System.Threading;

namespace Keda.CosmosDb.Scaler.Demo.OrderGenerator
{
    internal static class Program
    {
        private static CosmosDbConfig _cosmosDbConfig;

        public static async Task Main(string[] args)
        {

            // _cosmosDbConfig should be initialized once the host is built.
            Host.CreateDefaultBuilder(args)
                .ConfigureAppConfiguration(builder => _cosmosDbConfig = CosmosDbConfig.Create(builder.Build()))
                .Build();


            bool singlePartition=true;
            int count=10;
            bool runOnce = false;

            if (args.Length > 0)
            {
                bool.TryParse(args[0], out runOnce);
            }
            if (args.Length > 1)
            {
                bool.TryParse(args[1], out singlePartition);
            }
            if (args.Length > 2)
            {
                int.TryParse(args[2], out count);
            }

            Console.WriteLine($"Generating {count} orders  with singlePartion :{singlePartition}. Loop will exit after one run :{runOnce}");

            string article = singlePartition ? new Commerce().Product() : null;

            while (true)
            {
                await GenerateAsync(article, count);

                if (runOnce)
                    return;

                Thread.Sleep(1000);
            }
        }

        private static async Task GenerateAsync(string article, int count)
        {
            await CreateOrdersAsync(count, article);
        }

        
        private static async Task CreateOrdersAsync(int count, string article)
        {
            
            Container container;
            if (string.IsNullOrEmpty(_cosmosDbConfig.Connection))
            {
                var credential = new DefaultAzureCredential();

                container = new CosmosClient(_cosmosDbConfig.Endpoint, credential)
                    .GetContainer(_cosmosDbConfig.DatabaseId, _cosmosDbConfig.ContainerId);
            }
            else
            {
                container = new CosmosClient(_cosmosDbConfig.Connection)
                   .GetContainer(_cosmosDbConfig.DatabaseId, _cosmosDbConfig.ContainerId);
            }


            Task[] createOrderTasks = Enumerable.Range(0, count)
                .Select(_ => CreateOrderAsync(container, article))
                .ToArray();

            await Task.WhenAll(createOrderTasks);

           
        }

        private static async Task CreateOrderAsync(Container container, string article)
        {
            Customer customer = new Faker<Customer>()
                .RuleFor(customer => customer.FirstName, faker => faker.Name.FirstName())
                .RuleFor(customer => customer.LastName, faker => faker.Name.LastName());

            Order order = new Faker<Order>()
                .RuleFor(order => order.Customer, () => customer)
                .RuleFor(order => order.Amount, faker => faker.Random.Number(1, 10))
                .RuleFor(order => order.Article, faker => article ?? faker.Commerce.Product());

            Console.WriteLine($"Creating order {order.Id} - {order.Amount} unit(s) of {order.Article} for {order.Customer.FirstName} {order.Customer.LastName}");
            await container.CreateItemAsync(order);
        }

     
    }
}
