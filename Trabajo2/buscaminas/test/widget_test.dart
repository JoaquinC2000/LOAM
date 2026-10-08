import 'package:flutter_test/flutter_test.dart';

import 'package:buscaminas/models/minesweeper.dart';

/// Pruebas de la lógica del buscaminas (sin interfaz).
/// Se corren con: flutter test
void main() {
  test('el primer toque nunca es una mina y pone la cantidad correcta de minas', () {
    final board = MinesweeperBoard(Difficulty.facil);
    final result = board.reveal(0, 0);

    expect(result, isNot(RevealResult.mine));
    final mines = board.grid.expand((r) => r).where((c) => c.hasMine).length;
    expect(mines, Difficulty.facil.mines);
  });

  test('los números cuentan bien las minas vecinas', () {
    final board = MinesweeperBoard(Difficulty.medio);
    board.reveal(5, 5);
    for (final cell in board.grid.expand((r) => r)) {
      final real = board.neighbors(cell).where((n) => n.hasMine).length;
      expect(cell.adjacentMines, real);
    }
  });

  test('no se pueden poner más banderas que minas', () {
    final board = MinesweeperBoard(Difficulty.facil);
    board.reveal(0, 0);
    var placed = 0;
    for (final cell in board.grid.expand((r) => r)) {
      if (!cell.isRevealed) {
        board.toggleFlag(cell.row, cell.col);
        placed++;
      }
    }
    expect(placed, greaterThan(Difficulty.facil.mines));
    expect(board.flagsLeft, 0);
  });
}
