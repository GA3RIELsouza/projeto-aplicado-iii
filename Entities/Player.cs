namespace ProjetoAplicadoIII.Entities
{
    public sealed class Player : Entity
    {
        public string Name { get; set; } = string.Empty;
        public decimal Score { get; set; } = decimal.Zero;
    }
}
