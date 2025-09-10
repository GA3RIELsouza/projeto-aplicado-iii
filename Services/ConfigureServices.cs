namespace ProjetoAplicadoIII.Services
{
    public static class ConfigureServices
    {
        public static void RegisterServices(this IServiceCollection services)
        {
            services.AddSingleton<ClickerState>();
        }
    }
}
