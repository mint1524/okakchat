const agentTools = [
  {
    'type': 'function',
    'function': {
      'name': 'read_file',
      'description': 'Read the contents of a file',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Absolute path to the file'}
        },
        'required': ['path']
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'list_directory',
      'description': 'List files and directories at a path',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'}
        },
        'required': ['path']
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'search_files',
      'description': 'Regex search across files in a directory',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'pattern': {'type': 'string'},
          'glob': {'type': 'string', 'description': 'e.g. **/*.dart'}
        },
        'required': ['path', 'pattern']
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'write_file',
      'description': 'Write or overwrite a file with given content',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'content': {'type': 'string'}
        },
        'required': ['path', 'content']
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'edit_file',
      'description': 'Make targeted edits using find/replace blocks',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'edits': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'oldText': {'type': 'string'},
                'newText': {'type': 'string'}
              }
            }
          }
        },
        'required': ['path', 'edits']
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'execute_command',
      'description': 'Execute a shell command in the workspace directory',
      'parameters': {
        'type': 'object',
        'properties': {
          'command': {'type': 'string'},
          'workingDir': {'type': 'string'}
        },
        'required': ['command']
      },
    },
  },
];
