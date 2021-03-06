from Config.currency import retryCount, currencyLog, ErrorMax,timeSleep, TESTPATH
from Common.timeOperate import returnDayTimePng
from Common.openDriver import openWebdriverMax,openWebdriverNoUI
from Common.myJudge import judgeFindWay
from time import sleep
from Common.myLog import zLog

# 实例化log模块
elementLog = currencyLog

def retryMessage(message, way, surplus, dr):
	"""
	回复重试的信息
	:param message:
	:param way:
	:param surplus:
	:param dr:
	:return:
	"""
	errorPng = returnDayTimePng("../Report/UI/ErrorPng/", dr)
	elementLog.logger.warning(way + ":" + message + "失败！" + " 已尝试" + str(surplus) + "次，错误图片存放位置：" + errorPng)


def findElement(path, message, way, dr):
	"""
	:Usage:
		多次尝试寻找元素，尝试次数为Config.currency下定义的retryCount定义的次数
	:param path:str 具体路径
	:param message:str 寻找内容描述
	:param way:str way:css/xpath/id（三种查询方式）
	:param dr: dr:driver
	:return: 查询结果
	"""
	# 定义重试次数
	pd = retryCount
	while pd > 0:
		try:
			element = judgeFindWay(path, way, dr)
			if element != []:
				elementLog.logger.info("已找到：" + message)
				pd = 0
				return element
			else:
				pd -= 1
				if pd == 0:
					retryMessage(message, "寻找", retryCount, dr)
					elementLog.logger.error(ErrorMax)
				else:
					surplus = retryCount - pd
					retryMessage(message, "寻找", surplus, dr)
					sleep(timeSleep)
		except:
			pd -= 1
			surplus = retryCount - pd
			retryMessage(message, "寻找", surplus, dr)
			return False


def findElementAndClick(path, message, way, dr):
	"""
		:Usage:
			多次尝试寻找元素，尝试次数为Config.currency下定义的retryCount定义的次数
		:param path:str 具体路径
		:param message:str 寻找内容描述
		:param way:str way:css/xpath/id（三种查询方式）
		:param dr: dr:driver
		:return: 结果
		"""
	pd = retryCount
	while pd > 0:
		try:
			element = findElement(path, message, way, dr)
			element.click()
			elementLog.logger.info("点击：" + message + "成功！")
			pd = 0
			return True
		except:
			pd -= 1
			if pd == 0:
				retryMessage(message, "点击", retryCount, dr)
				elementLog.logger.error(ErrorMax)
				return False
			else:
				surplus = retryCount - pd
				retryMessage(message, "点击", surplus, dr)
				sleep(timeSleep)


def clearAndSend(path, message,sedmessage, way, dr):
	"""
	清空input框并输入message中的内容
	:param path:str 具体路径
	:param message:str 寻找内容描述
	:param sedmessage:str 输入内容
	:param way:str way:css/xpath/id（三种查询方式）
	:param dr: dr:driver 
	:return: 结果
	"""
	pd = retryCount
	while pd > 0:
		try:
			element = findElement(path, message, way, dr)
			element.clear()
			element.send_keys(sedmessage)
			elementLog.logger.info("输入：" + sedmessage + "成功！")
			pd = 0
			return True
		except:
			pd -= 1
			if pd == 0:
				retryMessage(sedmessage, "输入", retryCount, dr)
				elementLog.logger.error(ErrorMax)
				return False
			else:
				surplus = retryCount - pd
				retryMessage(sedmessage, "输入", surplus, dr)
				sleep(timeSleep)
	pass


def returnHTMLFullScreenCapture(htmlPath, filePath):
	"""
		返回全屏截图
	:param htmlPath: 必须使用系统绝对路径
	:param filePath: 生成文件路径
	:return:
	"""
	try:
		dr = openWebdriverNoUI()
		dr.get("file:" + htmlPath)
		sleep(1)
		# 获取高和宽
		width = dr.execute_script("return document.documentElement.scrollWidth")
		height = dr.execute_script("return document.documentElement.scrollHeight")
		# print(width, height)
		# 将浏览器的宽高设置成刚刚获取的宽高
		dr.set_window_size(width, height)
		sleep(1)
		# 截图并关掉浏览器
		# print(filePath)
		dr.save_screenshot(filePath)
		dr.close()
	except:
		elementLog.logger.error("error!")


if __name__ == '__main__':

	# # def testa():
	# # 	print("aaaaa")
	# dr = openWebdriverMax()
	# # judgeOS(testa(), "输出aaa")
	# dr.get("https://www.baidu.com/")
	# # a= dr.find_element_by_id("kw")
	# # a.send_keys('selenium')
	# clearAndSend("span>input#kw", "搜索框", "自动化测试", "css", dr)
	# findElementAndClick("span>input#su", "提交按钮", "css", dr)
	# dr.close()

	returnHTMLFullScreenCapture(TESTPATH + "\Report\DiskPerformance\Report\\2021-05-19\\indexDemo.html",   TESTPATH + "\Report\DiskPerformance\Report\\2021-05-19\\all.png")



