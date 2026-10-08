import 'dart:math';

/// Dificultades del juego: tamaño del tablero, cantidad de minas,
/// tiempo del modo contrarreloj y puntos por casilla.
enum Difficulty {
  facil('Fácil', cols: 8, rows: 10, mines: 10, timeLimit: 120, pointsPerCell: 1, winBonus: 100, diamondReward: 5),
  medio('Medio', cols: 10, rows: 14, mines: 25, timeLimit: 300, pointsPerCell: 2, winBonus: 250, diamondReward: 10),
  dificil('Difícil', cols: 12, rows: 18, mines: 45, timeLimit: 540, pointsPerCell: 3, winBonus: 500, diamondReward: 20);

  const Difficulty(
    this.label, {
    required this.cols,
    required this.rows,
    required this.mines,
    required this.timeLimit,
    required this.pointsPerCell,
    required this.winBonus,
    required this.diamondReward,
  });

  final String label;
  final int cols;
  final int rows;
  final int mines;

  /// Segundos disponibles en el modo contrarreloj.
  final int timeLimit;
  final int pointsPerCell;
  final int winBonus;
  final int diamondReward;
}

/// Modo de juego.
enum GameMode {
  normal('Normal', 'El tiempo suma, sin límite'),
  contrarreloj('Contrarreloj', 'Ganale al reloj antes de que llegue a cero');

  const GameMode(this.label, this.description);
  final String label;
  final String description;
}

/// Una casilla del tablero.
class Cell {
  Cell(this.row, this.col);

  final int row;
  final int col;
  bool hasMine = false;
  bool isRevealed = false;
  bool isFlagged = false;

  /// Cantidad de minas en las 8 casillas vecinas.
  int adjacentMines = 0;

  /// Marca la mina que explotó, para pintarla distinto.
  bool exploded = false;
}

/// Resultado de tocar una casilla.
enum RevealResult { nothing, safe, mine }

/// Resultado de usar la lupa sobre una casilla.
enum ProbeResult { invalid, safe, mine }

/// Toda la lógica del buscaminas. No sabe nada de Flutter:
/// solo maneja datos, así se puede explicar y probar por separado.
class MinesweeperBoard {
  MinesweeperBoard(this.difficulty) {
    _createEmptyGrid();
  }

  final Difficulty difficulty;
  final Random _random = Random();
  late List<List<Cell>> grid;

  /// Las minas se ponen recién en el primer toque, así nunca perdés de entrada.
  bool minesPlaced = false;
  bool isLost = false;
  bool isWon = false;

  int get rows => difficulty.rows;
  int get cols => difficulty.cols;
  int get totalMines => difficulty.mines;

  int get flagsPlaced => _allCells.where((c) => c.isFlagged).length;
  int get flagsLeft => totalMines - flagsPlaced;
  int get revealedCount => _allCells.where((c) => c.isRevealed && !c.hasMine).length;

  Iterable<Cell> get _allCells => grid.expand((row) => row);

  void _createEmptyGrid() {
    grid = List.generate(rows, (r) => List.generate(cols, (c) => Cell(r, c)));
  }

  /// Nueva partida: tablero vacío, las minas se sortean en el primer toque.
  void reset() {
    _createEmptyGrid();
    minesPlaced = false;
    isLost = false;
    isWon = false;
  }

  /// Reiniciar: mismas minas, todo tapado de nuevo.
  void restartSameBoard() {
    for (final cell in _allCells) {
      cell.isRevealed = false;
      cell.isFlagged = false;
      cell.exploded = false;
    }
    isLost = false;
    isWon = false;
  }

  /// Devuelve las casillas vecinas (hasta 8).
  List<Cell> neighbors(Cell cell) {
    final result = <Cell>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = cell.row + dr;
        final c = cell.col + dc;
        if (r >= 0 && r < rows && c >= 0 && c < cols) {
          result.add(grid[r][c]);
        }
      }
    }
    return result;
  }

  /// Sortea las minas evitando la casilla tocada y sus vecinas,
  /// para que el primer toque siempre abra una zona.
  void _placeMines(Cell safeCell) {
    final forbidden = {safeCell, ...neighbors(safeCell)};
    final candidates = _allCells.where((c) => !forbidden.contains(c)).toList()..shuffle(_random);
    for (final cell in candidates.take(totalMines)) {
      cell.hasMine = true;
    }
    for (final cell in _allCells) {
      cell.adjacentMines = neighbors(cell).where((n) => n.hasMine).length;
    }
    minesPlaced = true;
  }

  /// Destapa una casilla. Si no tiene minas alrededor, destapa en cadena.
  RevealResult reveal(int row, int col) {
    if (isLost || isWon) return RevealResult.nothing;
    final cell = grid[row][col];
    if (cell.isRevealed || cell.isFlagged) return RevealResult.nothing;

    if (!minesPlaced) _placeMines(cell);

    if (cell.hasMine) {
      cell.isRevealed = true;
      cell.exploded = true;
      isLost = true;
      return RevealResult.mine;
    }

    _floodReveal(cell);
    _checkWin();
    return RevealResult.safe;
  }

  /// Destape en cadena (búsqueda en anchura con una cola).
  void _floodReveal(Cell start) {
    final queue = <Cell>[start];
    while (queue.isNotEmpty) {
      final cell = queue.removeLast();
      if (cell.isRevealed || cell.isFlagged || cell.hasMine) continue;
      cell.isRevealed = true;
      if (cell.adjacentMines == 0) {
        queue.addAll(neighbors(cell).where((n) => !n.isRevealed));
      }
    }
  }

  /// Pone o saca una bandera.
  void toggleFlag(int row, int col) {
    if (isLost || isWon) return;
    final cell = grid[row][col];
    if (cell.isRevealed) return;
    if (!cell.isFlagged && flagsLeft <= 0) return;
    cell.isFlagged = !cell.isFlagged;
  }

  void _checkWin() {
    final safeCells = rows * cols - totalMines;
    if (revealedCount == safeCells) {
      isWon = true;
      // Al ganar, se marcan solas todas las minas con bandera.
      for (final cell in _allCells.where((c) => c.hasMine)) {
        cell.isFlagged = true;
      }
    }
  }

  /// Muestra todas las minas (cuando perdés).
  void revealAllMines() {
    for (final cell in _allCells.where((c) => c.hasMine)) {
      cell.isRevealed = true;
    }
  }

  /// Segunda vida: tapa la mina que explotó y le pone bandera.
  void undoExplosion() {
    for (final cell in _allCells.where((c) => c.exploded)) {
      cell.exploded = false;
      cell.isRevealed = false;
      cell.isFlagged = true;
    }
    isLost = false;
  }

  // ---------- Poderes que se pagan con diamantes ----------

  /// Lupa: el jugador elige una casilla tapada y la revisa sin riesgo.
  /// - Si es segura, la destapa y muestra su número.
  /// - Si es una mina, le pone una bandera (no explota).
  ProbeResult probe(int row, int col) {
    if (!minesPlaced || isLost || isWon) return ProbeResult.invalid;
    final cell = grid[row][col];
    if (cell.isRevealed || cell.isFlagged) return ProbeResult.invalid;

    if (cell.hasMine) {
      // Si no quedan banderas, saca una mal puesta para hacer lugar.
      if (flagsLeft <= 0) {
        final wrong = _allCells.where((c) => c.isFlagged && !c.hasMine).toList();
        if (wrong.isNotEmpty) wrong.first.isFlagged = false;
      }
      cell.isFlagged = true;
      return ProbeResult.mine;
    }

    _floodReveal(cell);
    _checkWin();
    return ProbeResult.safe;
  }

  /// Radar: pone una bandera correcta sobre una mina al azar.
  bool useRadar() {
    if (!minesPlaced) return false;
    final options = _allCells.where((c) => c.hasMine && !c.isFlagged).toList();
    if (options.isEmpty) return false;
    // Si ya usaste todas las banderas, saca una mal puesta para hacer lugar.
    if (flagsLeft <= 0) {
      final wrong = _allCells.where((c) => c.isFlagged && !c.hasMine).toList();
      if (wrong.isEmpty) return false;
      wrong.first.isFlagged = false;
    }
    options[_random.nextInt(options.length)].isFlagged = true;
    return true;
  }
}
