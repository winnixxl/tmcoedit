from flask import Flask, request, jsonify, session
from flask_restful import Resource, Api, reqparse
import sqlite3

app = Flask(__name__)
api = Api(app)

database = sqlite3.connect('tmcoedit.sqlite')
database_cursor = database.cursor()
database_cursor.execute('DROP TABLE IF EXISTS block;')
database_cursor.execute('''CREATE TABLE block (
    session_id VARCHAR NOT NULL,
    player VARCHAR,
    block_index INTEGER,
    name VARCHAR,
    dir INTEGER,
    coord_x INTEGER,
    coord_y INTEGER,
    coord_z INTEGER,
    freeBlock INTEGER,
    state INTEGER);'''
)
blocks = database_cursor.fetchall()
database.commit()

def saveBlocks(blocks, session_id, player):
    database = sqlite3.connect('tmcoedit.sqlite')
    database_cursor = database.cursor()
    database_cursor.execute("SELECT MAX(block_index) FROM block WHERE session_id = ?", [session_id])
    block_index = database_cursor.fetchone()[0]
    if block_index == None:
        block_index = 0

    for block in blocks:
        block_index += 1
        block += [session_id, player, block_index]

    database_cursor.executemany(
        'INSERT INTO block (name, dir, coord_x, coord_y, coord_z, freeBlock, state, session_id, player, block_index) VALUES (?,?,?,?,?,?,?,?,?,?)',
        blocks
    )
    database.commit()

def loadBlocks(session_id, player, block_index):
    database = sqlite3.connect('tmcoedit.sqlite')
    database_cursor = database.cursor()
    database_cursor.execute('SELECT * FROM block WHERE session_id = ? AND player <> ? AND block_index > ?', [session_id, player, block_index])
    blocks = database_cursor.fetchall()
    database.commit()
    return blocks

class Session(Resource):
    def get(self, session_id):
        return {
            'id': 'key123',
            'expires': 21937456,
            'url': 'http://localhost:8180/session/key123'
        }

class Blocks(Resource):
    def get(self, session_id, start_index):
        return {}

    def post(self, session_id, start_index):
        requestData = request.get_json()
        if(len(requestData['blocks']) > 0):
            saveBlocks(requestData['blocks'], session_id, requestData['player'])
        return {
            'success': True,
            'blocks': loadBlocks(session_id, requestData['player'], start_index)
        }


api.add_resource(Session, '/session/<session_id>') # Route_1 # General data about a session
api.add_resource(Blocks, '/blocks/<session_id>/<start_index>') # Added and removed Blocks starting from start_index

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8180)