import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Scaffold(
      appBar: AppBar(title: const Text('Instrucciones')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth < 380 ? 14.0 : 22.0;
            final contentWidth = (constraints.maxWidth - padding * 2)
                .clamp(0, 1100)
                .toDouble();
            final columns = contentWidth >= 760 ? 2 : 1;
            final cardWidth = columns == 1
                ? contentWidth
                : (contentWidth - 14) / columns;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView(
                  padding: EdgeInsets.all(padding),
                  children: [
                    Text(
                      'INSTRUCCIONES DE JUEGO – MAZE ADVENTURE',
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: contentWidth < 360 ? 20 : 26,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.forest, colors.ink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.explore_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Domina el laberinto, reúne recursos y descubre la salida.',
                              style: TextStyle(
                                color: colors.background,
                                fontSize: contentWidth < 380 ? 16 : 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _InstructionCard(
                            icon: Icons.flag_rounded,
                            title: 'OBJETIVO DEL JUEGO',
                            children: const [
                              Text(
                                'Recorre cada laberinto, supera obstáculos, derrota a los guardianes, reúne estrellas y alcanza la salida. En los mundos con cerradura, consigue la llave antes de llegar a la meta.',
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Lanza el dado para obtener pasos. Cada casilla válida consume uno; las paredes y obstáculos bloquean el movimiento sin gastar pasos.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _InstructionCard(
                            icon: Icons.keyboard_rounded,
                            title: 'CONTROLES DE COMPUTADORA',
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: const [
                                  _KeyHint(keys: 'W  A  S  D', action: 'Mover'),
                                  _KeyHint(keys: '↑  ←  ↓  →', action: 'Mover'),
                                  _KeyHint(keys: 'ESPACIO', action: 'Atacar'),
                                  _KeyHint(keys: 'E', action: 'Interactuar'),
                                  _KeyHint(keys: 'SHIFT', action: 'Escudo'),
                                  _KeyHint(keys: 'ESC', action: 'Pausar'),
                                  _KeyHint(keys: '1  2  3  4', action: 'Poder'),
                                  _KeyHint(keys: 'R', action: 'Lanzar dado'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Mantén WASD o una flecha para repetir el movimiento cuando tengas pasos disponibles.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _InstructionCard(
                            icon: Icons.touch_app_rounded,
                            title: 'CONTROLES MÓVILES',
                            children: const [
                              _InstructionBullet(
                                icon: Icons.gamepad_rounded,
                                text: 'Pulsa la cruceta para elegir dirección; cada paso válido consume una casilla del dado.',
                              ),
                              _InstructionBullet(
                                icon: Icons.swipe_rounded,
                                text: 'También puedes deslizar sobre el laberinto para moverte.',
                              ),
                              _InstructionBullet(
                                icon: Icons.local_fire_department_rounded,
                                text: 'Usa los botones ATACAR, ESCUDO e INTERACTUAR del panel táctil.',
                              ),
                              _InstructionBullet(
                                icon: Icons.pause_rounded,
                                text: 'El botón de pausa está en la parte superior de la partida.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _InstructionCard(
                            icon: Icons.auto_awesome_rounded,
                            title: 'ARMAS Y PODERES',
                            children: const [
                              _PowerLine(
                                icon: '🔥',
                                title: 'Bolas de fuego',
                                detail: 'Proyectil de alcance limitado; cuesta 18 de energía. Daña enemigos, cajas, telarañas, plantas y muros agrietados.',
                              ),
                              _PowerLine(
                                icon: '⚔️',
                                title: 'Espada mágica',
                                detail: 'Ataque cercano sin munición. Rompe cajas, telarañas y plantas espinosas.',
                              ),
                              _PowerLine(
                                icon: '➶',
                                title: 'Dardos',
                                detail: 'Munición limitada y alcance medio. Se reponen al recoger estrellas; pueden activar mecanismos a distancia.',
                              ),
                              _PowerLine(
                                icon: '🛡️',
                                title: 'Escudo mágico',
                                detail: 'Shift o el botón táctil consume 25 de energía y protege temporalmente. Se desbloquea en el nivel 2.',
                              ),
                              _PowerLine(
                                icon: '⚡',
                                title: 'Rayo eléctrico',
                                detail: 'Cuesta 28 de energía. Rompe rocas frágiles, barreras mágicas y cristales; se desbloquea en el nivel 3.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _InstructionCard(
                            icon: Icons.construction_rounded,
                            title: 'OBSTÁCULOS Y ENEMIGOS',
                            children: const [
                              Text(
                                'Las cajas, telarañas y plantas responden al fuego o la espada. Rocas, barreras y cristales requieren energía eléctrica; los muros agrietados ceden al fuego o al rayo. Algunos necesitan más de un impacto.',
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Los guardianes patrullan el laberinto. Atácalos en la dirección hacia la que miras; observa su barra de vida y evita el contacto para conservar vidas.',
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Las puertas de salida marcadas con candado requieren las llaves del nivel. E recoge objetos próximos y puede activar barreras eléctricas.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _InstructionCard(
                            icon: Icons.stars_rounded,
                            title: 'RECOMPENSAS Y RECURSOS',
                            children: const [
                              _InstructionBullet(
                                icon: Icons.star_rounded,
                                text: 'Las estrellas aumentan la puntuación y recuperan energía y dardos.',
                              ),
                              _InstructionBullet(
                                icon: Icons.bolt_rounded,
                                text: 'Romper obstáculos o derrotar enemigos otorga puntos y energía.',
                              ),
                              _InstructionBullet(
                                icon: Icons.favorite_rounded,
                                text: 'Tienes tres vidas. El contacto con un enemigo causa daño; el escudo puede bloquearlo.',
                              ),
                              _InstructionBullet(
                                icon: Icons.key_rounded,
                                text: 'Las llaves abren la salida de los mundos que las requieren.',
                              ),
                              _InstructionBullet(
                                icon: Icons.lock_open_rounded,
                                text: 'Completa mundos para desbloquear el siguiente y nuevas habilidades.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _InstructionCard(
                            icon: Icons.public_rounded,
                            title: 'LOS CINCO MUNDOS',
                            children: const [
                              _WorldLine(
                                icon: '🌲',
                                title: 'Bosque encantado',
                                detail: 'Rocas, cajas y plantas espinosas.',
                              ),
                              _WorldLine(
                                icon: '🏚️',
                                title: 'Mansión del terror',
                                detail:
                                    'Llaves, fantasmas y linterna limitada.',
                              ),
                              _WorldLine(
                                icon: '🗿',
                                title: 'Templo de la jungla',
                                detail: 'Guardianes resistentes, ruinas y rocas frágiles.',
                              ),
                              _WorldLine(
                                icon: '🤖',
                                title: 'Laboratorio futurista',
                                detail: 'Barreras tecnológicas y cristales de energía.',
                              ),
                              _WorldLine(
                                icon: '🌋',
                                title: 'Reino de lava',
                                detail: 'El desafío final con guardianes poderosos.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _InstructionCard(
                            icon: Icons.lightbulb_rounded,
                            title: 'CONSEJOS DE AVENTURA',
                            children: const [
                              _InstructionBullet(
                                icon: Icons.casino_rounded,
                                text: 'Planifica cada tirada y cambia de dirección para aprovechar todos los pasos.',
                              ),
                              _InstructionBullet(
                                icon: Icons.bolt_rounded,
                                text: 'Reserva energía para los obstáculos que solo puede romper el rayo y para el escudo.',
                              ),
                              _InstructionBullet(
                                icon: Icons.visibility_rounded,
                                text: 'Mira la resistencia del obstáculo antes de repetir un ataque.',
                              ),
                              _InstructionBullet(
                                icon: Icons.key_rounded,
                                text: 'Busca las llaves antes de acercarte a una salida cerrada.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('REGRESAR AL MENÚ PRINCIPAL'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.coral),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.muted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            keys,
            style: TextStyle(
              color: colors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(action, style: TextStyle(color: colors.muted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _InstructionBullet extends StatelessWidget {
  const _InstructionBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forBrightness(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.forest, size: 18),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PowerLine extends StatelessWidget {
  const _PowerLine({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final String icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(detail),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WorldLine extends StatelessWidget {
  const _WorldLine({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final String icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(detail),
            ],
          ),
        ),
      ],
    ),
  );
}
