unit np.buffer.tests;

interface

uses
  SysUtils, np.buffer;

procedure RunBufferTests;

implementation

procedure RunBufferTests;
var
  b, parent, child, dummy: BufferRef;
  mem: TBytes;
  ptr_old: PByte;
  i: Integer;
  passed: Boolean;
  const
  TEST_PASSED = '[OK] ';
  TEST_FAILED = '[FAIL] ';
begin
  WriteLn('--- Starting Buffer Tests ---');

  // -------------------------------------------------------------
  // ТЕСТ 1: Оптимизация In-Place (рост без реаллокации)
  // -------------------------------------------------------------
  WriteLn('Test 1: In-Place Optimization (Capacity Test)');

  // 1. Создаем буфер на 100 байт
  b := Buffer.Create(100);
  // Сейчас: Capacity = 100, Length = 100.

  // Чтобы проверить оптимизацию, нужно уменьшить Length, сохранив Capacity.
  // TrimR уменьшает Length, но не трогает память.
  b.TrimR(90);
  // Теперь: Capacity = 100, Length = 10.

  // Запоминаем указатель на текущие данные
  ptr_old := b.ref;

  // 2. Пытаемся добавить 5 байт.
  // В "хвосте" есть 90 свободных байт. Должно сработать БЕЗ реаллокации.
  optimized_append(b, Buffer.Create(5));

  // Проверки:
  // Указатель должен остаться тем же самым
  if (b.ref = ptr_old) and (b.length = 15) then
    WriteLn(TEST_PASSED + 'Buffer grew in-place (pointer unchanged)')
  else
    WriteLn(TEST_FAILED + 'Buffer reallocated or pointer changed unexpectedly!');

  // 3. Пытаемся добавить ОЧЕНЬ много (больше 100 байт).
  // Должно не хватить места -> реаллокация
  optimized_append(b, Buffer.Create(150));

  if (b.ref <> ptr_old) then
    WriteLn(TEST_PASSED + 'Buffer reallocated when capacity exceeded')
  else
    WriteLn(TEST_FAILED + 'Buffer did not reallocate when full!');


  // -------------------------------------------------------------
  // ТЕСТ 2: WeakRef (проверка создания нового буфера)
  // -------------------------------------------------------------
  WriteLn('Test 2: WeakRef Safety');

  // 1. Создаем "внешний" массив
  SetLength(mem, 20);
  for i := 0 to 19 do mem[i] := $AA;

  // 2. Создаем WeakRef поверх него
  b := BufferRef.CreateWeakRef(@mem[0], 20);

  ptr_old := b.ref; // ptr_old указывает на mem[0]

  // 3. Добавляем данные.
  // WeakRef не должен расширяться "на месте", так как мы не управляем mem.
  // Должен создаться НОВЫЙ буфер.
  optimized_append(b, Buffer.Create(5));

  passed := True;

  // Указатель должен измениться (это новые данные, не наш mem)
  if b.ref = ptr_old then begin
    WriteLn(TEST_FAILED + 'CRITICAL: WeakRef pointer did not change!');
    passed := False;
  end;

  // Проверяем, что старые данные ($AA) скопировались в новый буфер
  if passed then begin
    for i := 0 to 19 do
      if b.ref[i] <> $AA then passed := False;

    if passed then
      WriteLn(TEST_PASSED + 'WeakRef correctly reallocated and data copied')
    else
      WriteLn(TEST_FAILED + 'WeakRef data copy failed (data corrupted)');
  end;


  // -------------------------------------------------------------
  // ТЕСТ 3: Слайс (защита от порчи родительского буфера)
  // -------------------------------------------------------------
  WriteLn('Test 3: Slice Isolation');

  // 1. Создаем родителя, заполняем числами
  parent := Buffer.Create(100);
  for i := 0 to 99 do parent.ref[i] := i; // 0..99

  // 2. Делаем слайс в середине (например, байты 20..30)
  child := parent.slice(20, 10);

  // Проверка: слайс должен видеть правильные данные (числа 20..29)
  passed := True;
  for i := 0 to 9 do
    if child.ref[i] <> (20 + i) then passed := False;

  if not passed then
    WriteLn(TEST_FAILED + 'Slice setup incorrect')
  else
    WriteLn(TEST_PASSED + 'Slice created correctly');

  ptr_old := child.ref;

  // 3. Добавляем данные к слайсу.
  // ОПАСНОСТЬ: Если optimized_append ошибочно решит, что можно писать в хвост,
  // он затрет родительские данные (байты 30+).
  optimized_append(child, Buffer.Create(5));

  // Проверки:

  // Слайс должен был "переезжать" (реаллокация), так как он не в начале памяти
  if child.ref = ptr_old then begin
    WriteLn(TEST_FAILED + 'CRITICAL: Slice grew in-place! Parent corrupted!');
    // Даже если мы тут увидим ошибку, проверим родителя ниже
  end else begin
    WriteLn(TEST_PASSED + 'Slice reallocated to new memory');
  end;

  // Проверяем родителя!
  // Байт с индексом 30 должен остаться равен 30 (не затерт новыми данными от child)
  if parent.ref[30] <> 30 then
    WriteLn(TEST_FAILED + 'CRITICAL: Parent buffer corrupted at offset 30!')
  else
    WriteLn(TEST_PASSED + 'Parent buffer is safe and sound');

  // Проверяем данные самого слайса (первые 10 байт должны сохраниться)
  passed := True;
  for i := 0 to 9 do
    if child.ref[i] <> (20 + i) then passed := False;

  if passed then
    WriteLn(TEST_PASSED + 'Slice data integrity preserved')
  else
    WriteLn(TEST_FAILED + 'Slice data corrupted after reallocation');


  b := Buffer.Create([1,2,3,4,5,6,7,8,9,10]);

  if b.same(Buffer.CreateFromBase64(b.ToBase64())) then
    WriteLn(TEST_PASSED + 'S->Base64->S : ' + b.ToString() + ' =  ' + Buffer.CreateFromBase64(b.ToBase64()).ToString())
  else
    WriteLn(TEST_FAILED + 'S->Base64->S : ' + b.ToString() + ' <> ' + Buffer.CreateFromBase64(b.ToBase64()).ToString());

  WriteLn('--- Tests Finished ---');
end;

end.
