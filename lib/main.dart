import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

late final Future<Database> database;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  database = openDatabase(
    join(await getDatabasesPath(), 'tasks_database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY, title TEXT, description TEXT, dueDate INTEGER, isCompleted INTEGER)',
      );
    },
    version: 1,
  );

  runApp(MyApp());
}

class Task {
  int id;
  String title;
  String? description;
  DateTime? dueDate;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TodoList',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ToDoListScreen(),
    );
  }
}

class ToDoListScreen extends StatefulWidget {
  @override
  _ToDoListScreenState createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _dueDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Задачи'),
      ),
      body: FutureBuilder<List<Task>>(
        future: _fetchTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data?.length ?? 0,
              itemBuilder: (context, index) {
                final task = snapshot.data![index];
                return ListTile(
                  title: Text(task.title),
                  subtitle: _buildSubtitle(task),
                  trailing: IconButton(
                    icon: task.isCompleted
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : Icon(Icons.circle_outlined),
                    onPressed: () {
                      _toggleTaskCompletion(task);
                    },
                  ),
                  onTap: () {
                    _editTask(context, task);
                  },
                  onLongPress: () {
                    _deleteTask(task);
                  },
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddTaskDialog(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget? _buildSubtitle(Task task) {
    if (task.description != null && task.dueDate != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.description!),
          SizedBox(height: 4),
          Row(
            children: [
              if (task.dueDate!.isBefore(DateTime.now().add(Duration(days: 7))))
                Text(_formatTimeRemaining(task.dueDate!)),
            ],
          ),
        ],
      );
    } else if (task.description != null) {
      return Text(task.description!);
    } else if (task.dueDate != null) {
      return Row(
        children: [
          Text(_formatDueDate(task.dueDate!)),
          SizedBox(width: 8),
          if (task.dueDate!.isBefore(DateTime.now().add(Duration(days: 7))))
            Text(_formatTimeRemaining(task.dueDate!)),
        ],
      );
    } else {
      return null;
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final formattedDate = DateFormat('dd-MMM').format(dueDate);
    return '$formattedDate';
  }

  String _formatTimeRemaining(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    if (difference.inDays > 0) {
      return '${difference.inDays} дней осталось';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} часов осталось';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} минут осталось';
    } else {
      return '${DateFormat('dd-MMM').format(dueDate)} ${DateFormat('hh:mm').format(dueDate)}';
    }
  }

  Future<List<Task>> _fetchTasks() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');

    return List.generate(maps.length, (i) {
      return Task(
        id: maps[i]['id'],
        title: maps[i]['title'],
        description: maps[i]['description'],
        dueDate: maps[i]['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(maps[i]['dueDate']) : null,
        isCompleted: maps[i]['isCompleted'] == 1 ? true : false,
      );
    });
  }

  Future<void> _insertTask(Task task) async {
    final Database db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _updateTask(Task task) async {
    final Database db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> _deleteTask(Task task) async {
    final Database db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [task.id],
    );
    setState(() {});
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Добавить задачу'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Название'),
                  onChanged: (value) {},
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: 'Описание'),
                  onChanged: (value) {},
                ),
                ListTile(
                  title: Text('Срок задачи'),
                  subtitle: _dueDate != null ? Text(_formatDueDate(_dueDate!)) : null,
                  onTap: () {
                    _selectDueDate(context);
                  },
                  trailing: _dueDate != null
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _dueDate = null;
                            });
                          },
                        )
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final newTask = Task(
                  id: 0,
                  title: _titleController.text.trim(),
                  description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                  dueDate: _dueDate,
                  isCompleted: false,
                );
                _insertTask(newTask).then((_) {
                  setState(() {});
                  Navigator.of(context).pop();
                });
              },
              child: Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  void _editTask(BuildContext context, Task task) {
    _titleController.text = task.title;
    _descriptionController.text = task.description ?? '';
    _dueDate = task.dueDate;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Редактировать'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Название'),
                  onChanged: (value) {},
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: 'Описание'),
                  onChanged: (value) {},
                ),
                ListTile(
                  title: Text('Срок задачи'),
                  subtitle: _dueDate != null ? Text(_formatDueDate(_dueDate!)) : null,
                  onTap: () {
                    _selectDueDate(context);
                  },
                  trailing: _dueDate != null
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _dueDate = null;
                            });
                          },
                        )
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final updatedTask = Task(
                  id: task.id,
                  title: _titleController.text.trim(),
                  description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                  dueDate: _dueDate,
                  isCompleted: task.isCompleted,
                );
                _updateTask(updatedTask).then((_) {
                  setState(() {});
                  Navigator.of(context).pop();
                });
              },
              child: Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  void _selectDueDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _dueDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      isCompleted: !task.isCompleted,
    );
    await _updateTask(updatedTask);
    setState(() {});
  }
}
