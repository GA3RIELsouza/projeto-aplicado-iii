using Microsoft.AspNetCore.SignalR;
using ProjetoAplicadoIII.Entities;
using ProjetoAplicadoIII.Hubs;

namespace ProjetoAplicadoIII.Services
{
    public class ClickerState(IHubContext<ClickerHub> hub)
    {
        private readonly IHubContext<ClickerHub> _hub = hub;
        private readonly object _lock = new();

        public bool IsInGame { get; private set; } = false;
        public Player[] Players { get; private set; } = new Player[2];

        public event Action? OnChange;

        public async Task ToggleInGame()
        {
            lock (_lock)
            {
                IsInGame = !IsInGame;
            }

            await _hub.Clients.All.SendAsync(ClickerHub.IS_IN_GAME, IsInGame);

            NotifyStateChanged();
        }

        private void NotifyStateChanged() => OnChange?.Invoke();
    }
}
