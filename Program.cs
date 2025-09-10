using Microsoft.EntityFrameworkCore;
using ProjetoAplicadoIII.Components;
using ProjetoAplicadoIII.Infrastructure.Context;
using ProjetoAplicadoIII.Infrastructure.Interfaces;
using ProjetoAplicadoIII.Infrastructure.Repositories;
using ProjetoAplicadoIII.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

var dbConnStr = builder.Configuration.GetConnectionString("DatabaseConnection");

builder.Services.AddDbContext<SqliteDbContext>(options =>
{
    options.UseSqlite(dbConnStr, sqliteOptions =>
    {
        sqliteOptions.CommandTimeout(30);
    });
});

builder.Services.RegisterServices();

#region Repositories
builder.Services.AddScoped<IUserRepository, UserRepository>();
#endregion

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true)
        .UseHsts();
}

app.UseHttpsRedirection()
    .UseAntiforgery();

app.UseStaticFiles();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
