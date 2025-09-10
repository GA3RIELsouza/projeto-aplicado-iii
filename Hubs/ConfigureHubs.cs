namespace ProjetoAplicadoIII.Hubs
{
    public static class ConfigureHubs
    {
        public static void RegisterHubs(this WebApplication app)
        {
            app.MapHub<ClickerHub>("/clickerHub");
        }
    }
}
