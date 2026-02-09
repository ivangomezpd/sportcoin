# SportCoin (SPC) - Official Fan Token Design Document

## 1. Concepto del Token
**SportCoin (SPC)** es un token de utilidad (Utility Token) diseñado para fidelizar y recompensar la base de fans y jugadores de un club de fútbol profesional. A diferencia de los "Fan Tokens" especulativos comunes en mercados como Socios.com, SPC se centra en la **economía circular de compromiso**: 
*   **Ganar**: Por acciones verificables que aportan valor al club (asistencia, soporte a patrocinadores).
*   **Gastar**: En experiencias exclusivas, merchandising y gobernanza suave (votaciones menores).

El valor del token es **intrínseco al ecosistema del club**, no financiero.

## 2. Tokenomics
Diseñamos una economía sostenible que equilibra la inflación (emisión por actividad) con la deflación (quema/reciclaje por canje).

### Supply y Emisión
*   **Tipo**: Suministro Dinámico con Techo Blando (Soft Cap) o Emisión Ilimitada Responsable.
*   **Modelo de Emisión**: "Mint-on-Activity" (Acuñación por Actividad). Los tokens NO se pre-minan todos para venderlos. Se generan cuando ocurren los eventos (Proof-of-Engagement).
*   **Initial Supply**: Un fondo de reserva pequeño para marketing y airdrops iniciales a socios abonados.

### Flujo de Valor (Earn & Burn)
| Acción (Mining) | Cantidad | Frecuencia | Validación |
| :--- | :--- | :--- | :--- |
| **Asistencia a Patrocinador** (Evento) | 5 SPC | Por evento | Firma criptográfica de admin (QR/NFC) |
| **Compra en Patrocinador** (>50€) | 5 SPC | Ilimitado | API Patrocinador -> Oracle -> Contract |
| **Entrenamiento Oficial** (Público) | 15 SPC | Semanal | Geolocalización + Check-in App |
| **Partido Oficial** (En Estadio) | 10 SPC | Por partido | Torno Estadio (NFC) / Geolocación |

### Mecanismo de Control (Inflación/Deflación)
Para evitar que el token pierda atractivo por exceso de oferta:
1.  **Redemption Sinks (Sumideros)**: El canje de premios (ej. camiseta firmada = 500 SPC) **QUEMA** el 50% de los tokens y envia el 50% a la Tesorería del Club para futuros incentivos. Esto reduce el circulante activo.
2.  **Decay (Opcional)**: "Inactividad". Si una wallet no interactúa en 12 meses, sus puntos pueden decaer, incentivando el uso continuo.

## 3. Estándar del Token y Justificación
**Elección: Híbrido ERC-20 + ERC-721**

*   **Token Principal (SPC) -> ERC-20**:
    *   *Justificación*: Necesitamos fungibilidad. Un token ganado en un partido vale lo mismo que uno ganado en Mercadona. Es el estándar para "puntos" acumulables y divisibles (si fuera necesario, aunque usaremos enteros para UX).
*   **Badges/Logros -> ERC-721 (NFTs)**:
    *   *Justificación*: "Proof-of-Attendance" (POAP). Si un fan va a los 19 partidos de liga, recibe un NFT único "Super Fan Season 2024". Esto da estatus, mientras el ERC-20 da liquidez para premios.

## 4. Arquitectura Técnica
Debemos minimizar costes (Gas Fees) y fricción (UX para no-crypto natives).

### Stack Tecnológico
*   **Blockchain**: **Polygon (Polygon PoS)** o **Base (L2)**.
    *   *Razón*: Fees insignificantes (<$0.01), compatibilidad EVM total, ecosistema maduro de marcas.
*   **Gasless Experience (Meta-Transactions)**:
    *   El usuario **NO** paga gas. El club subvenciona las transacciones mediante un "Paymaster" (usando Biconomy, OpenGSN o Account Abstraction ERC-4337).
    *   Para el usuario, la App es "mágica", no sabe que hay blockchain detrás.

### Sistema de Verificación de Eventos (Oracle / "Proof-of-Something")
1.  **Eventos Físicos (Entrenamientos/Partidos)**:
    *   **Geofencing + QR Rotativo**: La App del usuario genera una prueba de ubicación GPS. En la entrada, escanean un QR que cambia cada 5 segundos (evita fotos compartidas por WhatsApp).
    *   **NFC**: Chips en los asientos o tornos que firman una transacción al acercar el móvil (seguridad alta).
2.  **Compras Patrocinadores (Mercadona, Decathlon)**:
    *   **API Oracle**: El TPV del patrocinador genera un código único en el ticket. El usuario lo escanea en la App. El backend consulta la API del patrocinador para validar el ticket y, si es válido, el backend (con rol `MINTER_ROLE`) emite los tokens on-chain a la wallet del usuario.

### Prevención de Fraude
*   **Doble Gasto / Doble Claim**: El Smart Contract registra `mapping(bytes32 => bool) processedTicketIds`. Un ticket de compra o evento solo puede usarse una vez.
*   **Bots**: Rate limiting en el backend. Requisito de KYC ligero (teléfono verificado) para crear la wallet.
*   **Geofencing**: El contrato puede requerir verificación firmada de coordenadas GPS (vía oráculo) para eventos de ubicación.

## 5. Smart Contracts (Diseño Lógico)

### A. `SportCoin.sol` (ERC-20)
*   **Roles**:
    *   `DEFAULT_ADMIN_ROLE`: Control total (Multisig del Club).
    *   `MINTER_ROLE`: Contratos autorizados (Rewards) y Backend del sistema.
*   **Extensions**: `ERC20Burnable`, `AccessControl`, `ERC20Permit` (para gasless approval).

### B. `EngagementRewards.sol`
*   Gestor de lógica de recompensas.
*   **Función**: `rewardUser(address user, uint256 amount, string eventId, bytes signature)`
*   Verifica que la `signature` venga de un signer autorizado por el club (backend verificado).

### C. `RedemptionStore.sol`
*   Catalogo de premios on-chain (o hash de catálogo off-chain).
*   **Función**: `redeemItem(uint256 itemId)`
    *   Transfiere SPC del usuario al contrato.
    *   Quema X% y envía Y% a Treasury.
    *   Emite evento `ItemRedeemed(user, itemId)` que el backend escucha para entregar el producto físico/digital.

## 6. Flujos de Usuario
1.  **Fan (Alice)**:
    *   Va al estadio. Abre App.
    *   Acerca móvil al torno NFC.
    *   App recibe señal -> envía tx firmada al Relayer -> Contract verifica -> Alice recibe 10 SPC.
    *   Notificación Push: "¡Goooool! Has recibido 10 SPC".
2.  **Jugador (Bob)**:
    *   Participa en evento benéfico.
    *   Club le envía 50 SPC como incentivo simbólico.
    *   Bob dona sus SPC a una ONG desde la App (la ONG los canjea por € donados por patrocinadores).

## 7. Compliance (Web3 Realista)
*   **NO Security**: El token no promete revalorización. No hay "staking financiero". Es un cupón digital glorificado.
*   **MiCA (Europa)**: Probablemente caiga bajo "Utility Token". Al no ser transferible por dinero fiat en exchanges oficiales (inicialmente), se reduce el riesgo regulatorio.
*   **Privacidad (GDPR)**: La blockchain solo guarda `address -> balance`. La vinculación `address -> DNI/Nombre` está en base de datos centralizada del club (custodia segura), no pública.

## 8. Siguiente Paso para MVP
1.  Desplegar contratos en **Polygon Amoy (Testnet)**.
2.  Crear **Script de Backend** (Node.js) que actúe como "Oracle" para firmar transacciones de rewards.
3.  Implementar `SportCoin.sol` con OpenZeppelin.
