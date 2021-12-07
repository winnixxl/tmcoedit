<?php

/**
 * This is an example implementation for TMCoEdit
 */

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$GLOBALS['expire'] = 60 * 60 * 4;

function main()
{
	if($_SERVER['REQUEST_METHOD'] === 'GET') {
		get();
	}

	if($_SERVER['REQUEST_METHOD'] === 'POST') {
		post();
	}
}

function get()
{
	$response = null;
	header('Content-Type: application/json');
	if(url(PHP_URL_PATH) === '/index.php' && url(PHP_URL_QUERY) === null) {
		$response = start_session();
		header("Location: " . $response['url']);
		exit();
	}
	
	if(isset($_GET['id'])) {
		$response = get_session($_GET['id']);
	}

	echo(json_encode($response));
}

function post()
{
	header('Content-Type: application/json');
	file_put_contents(
		'sessions/test',
		"\n" . file_get_contents('php://input'),
		FILE_APPEND,
	);

	echo("success");
}

function gen_id()
{
    return sprintf('%04x-%04x', mt_rand(0, 0xffff), mt_rand(0, 0xffff));
}

function start_session()
{
	$id = gen_id();
	$session_data = [
    	'start' => time(),
    	'id' => $id,
		'url' => url(PHP_URL_PATH) . '?id=' . $id,
    ];
	if (!file_exists('sessions')) {
		mkdir('sessions', 0777, true);
	}
	file_put_contents(
    	'sessions/' . $session_data['id'],
    	json_encode($session_data),
    );
    return $session_data;
}

function get_session($id, $from_index = 0)
{
	$file = fopen('sessions/' . $id, 'r');
	if($file === false){
    	return null;
    }
	$session_data = json_decode(fgets($file), true);
	$data = read_json($file, $from_index);
	fclose($file);

	return [
		'id' => $id,
		'expires' => $session_data['start'] - time() + $GLOBALS['expire'],
		'url' => url(PHP_URL_PATH) . '?id=' . $id,
		'data' => $data,
	];
}

function read_json($file, $from_index)
{
	$data = [];
	$i = 0;
	while(($line = fgets($file)) !== false) {
    	if($i < $from_index) {
        	continue;
        }
    	$data[$i] = json_decode($line, true);
    	$i++;
    }
	return $data;
}

function url($part)
{
	return parse_url($_SERVER['REQUEST_URI'], $part);
}

main();

?>
