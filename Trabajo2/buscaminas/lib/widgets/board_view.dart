import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/minesweeper.dart';

/// Dibuja el tablero del buscaminas con el estilo "césped y tierra".
/// No tiene lógica: solo muestra el tablero y avisa los toques.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.theme,
    required this.mineEmoji,
    required this.flagEmoji,
    required this.onCellTap,
    required this.onCellLongPress,
  });

  final MinesweeperBoard board;
  final BoardTheme theme;
  final String mineEmoji;
  final String flagEmoji;
  final void Function(int row, int col) onCellTap;
  final void Function(int row, int col) onCellLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tamaño de casilla para que el tablero entre completo en el espacio disponible.
        final cellSize = [
          (constraints.maxWidth - 12) / board.cols,
          (constraints.maxHeight - 12) / board.rows,
        ].reduce((a, b) => a < b ? a : b).floorToDouble();

        return Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < board.rows; r++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < board.cols; c++)
                          _CellView(
                            cell: board.grid[r][c],
                            size: cellSize,
                            theme: theme,
                            mineEmoji: mineEmoji,
                            flagEmoji: flagEmoji,
                            gameOver: board.isLost,
                            onTap: () => onCellTap(r, c),
                            onLongPress: () => onCellLongPress(r, c),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CellView extends StatelessWidget {
  const _CellView({
    required this.cell,
    required this.size,
    required this.theme,
    required this.mineEmoji,
    required this.flagEmoji,
    required this.gameOver,
    required this.onTap,
    required this.onLongPress,
  });

  final Cell cell;
  final double size;
  final BoardTheme theme;
  final String mineEmoji;
  final String flagEmoji;
  final bool gameOver;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Colores clásicos de los números, bien vivos.
  static const _numberColors = {
    1: Color(0xFF1976D2),
    2: Color(0xFF388E3C),
    3: Color(0xFFD32F2F),
    4: Color(0xFF7B1FA2),
    5: Color(0xFFFF8F00),
    6: Color(0xFF0097A7),
    7: Color(0xFF424242),
    8: Color(0xFF9E9E9E),
  };

  @override
  Widget build(BuildContext context) {
    // Patrón de cuadros (como un tablero de ajedrez).
    final even = (cell.row + cell.col) % 2 == 0;
    Color color;
    if (cell.isRevealed && cell.hasMine) {
      color = cell.exploded ? const Color(0xFFFF5252) : const Color(0xFFFF8A80);
    } else if (cell.isRevealed) {
      color = even ? theme.revealed : theme.revealedAlt;
    } else {
      color = even ? theme.covered : theme.coveredAlt;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: size,
        height: size,
        color: color,
        alignment: Alignment.center,
        child: _buildContent(),
      ),
    );
  }

  Widget? _buildContent() {
    final emojiStyle = TextStyle(fontSize: size * 0.58);

    if (cell.isRevealed && cell.hasMine) {
      return _PopIn(key: const ValueKey('mine'), child: Text(mineEmoji, style: emojiStyle));
    }
    if (cell.isFlagged) {
      // Si perdiste y la bandera estaba mal puesta, se marca con una cruz.
      final wrong = gameOver && !cell.hasMine;
      return _PopIn(
        key: ValueKey('flag$wrong'),
        child: Text(wrong ? '❌' : flagEmoji, style: emojiStyle),
      );
    }
    if (cell.isRevealed && cell.adjacentMines > 0) {
      return _PopIn(
        key: const ValueKey('number'),
        child: Text(
          '${cell.adjacentMines}',
          style: TextStyle(
            fontSize: size * 0.62,
            fontWeight: FontWeight.w900,
            color: _numberColors[cell.adjacentMines],
          ),
        ),
      );
    }
    return null;
  }
}

/// Pequeña animación de "aparecer rebotando".
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
