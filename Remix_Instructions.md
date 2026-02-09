# Cómo probar SportCoin en Remix

Sigue estos pasos para desplegar y probar los contratos en [Remix IDE](https://remix.ethereum.org/).

## 1. Preparación
1.  Abre Remix.
2.  Crea 3 archivos nuevos y copia el contenido de los contratos que he generado en tu carpeta `contracts/`:
    *   `SportCoin.sol`
    *   `EngagementRewards.sol`
    *   `RedemptionStore.sol`

## 2. Despliegue (Deploy)
Ve a la pestaña **"Deploy & Run Transactions"**.

### A. SportCoin (SPC)
1.  Selecciona el contrato `SportCoin`.
2.  Haz clic en **Deploy**.
3.  Copia la dirección del contrato desplegado (ej. `0xd91...`).

### B. EngagementRewards
1.  Selecciona el contrato `EngagementRewards`.
2.  En el constructor, introduce:
    *   `_token`: La dirección de `SportCoin` (pegada arriba).
    *   `_trustedSigner`: Tu propia dirección (Account 0) para pruebas, o una secundaria.
3.  Haz clic en **Deploy**.
4.  **Importante**: Vuelve a `SportCoin` y ejecuta la función `grantRole`:
    *   `role`: `0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6` (Este es el hash de `MINTER_ROLE`).
    *   `account`: La dirección del contrato `EngagementRewards`.
    *   *Nota*: Sin esto, EngagementRewards no podrá crear tokens.

### C. RedemptionStore
1.  Selecciona `RedemptionStore`.
2.  Constructor:
    *   `_token`: Dirección `SportCoin`.
    *   `_treasury`: Una dirección cualquiera (ej. Account 2).
3.  Haz clic en **Deploy**.

## 3. Pruebas de Flujo

### Prueba 1: Ganar Tokens (Reward) -> "Simulado"
Como generar firmas criptográficas manuales en Remix es complejo, para testear rápido puedes hacer un "truco" temporal en `EngagementRewards.sol`:
*   Cambia temporalmente `require(recoveredSigner == trustedSigner` por `// require...` para probar sin firmas, O BIEN:
*   Usa la función `mint` directa de `SportCoin` (ya que eres Admin) para darte tokens a ti mismo y probar la tienda.
    *   Ve a `SportCoin` -> `mint(TuDirección, 1000)`.

### Prueba 2: Comprar en Tienda (Redeem)
1.  En `RedemptionStore`, crea un item:
    *   `createItem("Bufanda", 100, 50)` (Nombre, Precio, Stock).
    *   Anota el `itemId` (será 0).
2.  En `SportCoin`, aprueba a la tienda para gastar tus tokens:
    *   `approve(DirecciónDeRedemptionStore, 100)`.
3.  En `RedemptionStore`, compra:
    *   `redeemItem(0)`.
4.  Verifica:
    *   Tu balance en `SportCoin` bajó 100.
    *   El balance de `_treasury` subió 50.
    *   El `totalSupply` de `SportCoin` bajó 50 (quema).
