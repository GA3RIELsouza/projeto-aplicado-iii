using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using ProjetoAplicadoIII.Entities;

namespace ProjetoAplicadoIII.Infrastructure.Context.Configuration
{
    public sealed class UserConfiguration : EntityConfiguration<User>
    {
        public override void Configure(EntityTypeBuilder<User> builder)
        {
            base.Configure(builder);

            builder.ToTable("user");

            builder.Property(x => x.Email)
                .HasColumnName("email")
                .HasMaxLength(254)
                .IsRequired(true);

            builder.Property(x => x.Password)
                .HasColumnName("password")
                .HasMaxLength(255)
                .IsRequired(true);

            builder.Property(x => x.Name)
                .HasColumnName("name")
                .HasMaxLength(64)
                .IsRequired(true);

            builder.Property(x => x.Active)
                .HasColumnName("active")
                .HasDefaultValue(true)
                .IsRequired(true);

            builder.HasData(new User
            {
                Id = 1,
                Email = "admin@admin.com",
                Password = "admin",
                Name = "Administrador",
                Active = true
            });
        }
    }
}
