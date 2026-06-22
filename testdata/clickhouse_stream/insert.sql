INSERT INTO default.access_local (
    org, id, ts, ts_ms, ip, sid, uid, url, channel, result, result_action,
    req_risk, data, url_action, ip_geo, ua_info,
    req_sens_k, req_sens_v, res_sens_k, res_sens_v,
    req, res
)
SELECT
    '' AS org,
    toString(rand64()) AS id,
    now() - toIntervalSecond(rand() % 864000) AS ts,
    toUnixTimestamp64Milli(now64()) + number AS ts_ms,
    if(number % 100000 = 0, '192.168.1.100',
        concat(toString(rand() % 223 + 1), '.', toString(rand() % 256), '.', toString(rand() % 256), '.', toString(rand() % 254 + 1))) AS ip,
    toString(rand64()) AS sid,
    concat('user_', toString(rand() % 50000)) AS uid,
    concat('/api/v1/', ['users','orders','products','search','login','data'][rand() % 6 + 1]) AS url,
    ['web','mobile','api'][rand() % 3 + 1] AS channel,
    ['pass','block','challenge','protect'][rand() % 4 + 1] AS result,
    ['allow','deny','redirect','log'][rand() % 4 + 1] AS result_action,
    [['sqli','xss'],['rce'],[''],['sqli','csrf'],['xss','rce']][rand() % 5 + 1] AS req_risk,
    ['10.0.1.1','node_01'] AS data,
    ['','api','','','公网','whisky','',''] AS url_action,
    [] AS ip_geo,
    ['Other','Other','browser','','Windows','10'] AS ua_info,
    if(number % 100000 = 0, ['phone','idcard'], []) AS req_sens_k,
    if(number % 100000 = 0, ['13800138000','110101199001011234'], []) AS req_sens_v,
    [] AS res_sens_k,
    [] AS res_sens_v,
    concat('{"Path":"', url, '","Host":"',
        ['www.example.com','api.example.com','admin.example.com'][rand() % 3 + 1],
        '","Method":"', ['GET','POST','PUT'][rand() % 3 + 1],
        '","Headers":{"User-Agent":["Mozilla/5.0 Test"]}","ClientIP":"', ip, '"}') AS req,
    '{"Status":200,"Headers":{"Content-Type":["application/json"]}}' AS res
FROM numbers(5000000);
